# Databricks audit-log delivery to Upwind, Databricks on GCP.
#
# Databricks pushes audit logs as JSON Lines files into a GCS bucket in the
# customer's project; the bucket publishes a Pub/Sub message on every write;
# Upwind pulls the subscription and reads the new lines.
#
#   - Databricks' log-delivery service account gets Storage Admin on the
#     bucket, which is what Databricks documents.
#   - Upwind's access is not created here. Upwind reads as the management
#     service account of the Upwind GCP onboarding, through the workload
#     identity federation that onboarding already set up: apply the
#     onboarding module with enable_dataevents = true, on a scope that
#     includes project_id. This module creates no identity, pool or grant
#     for Upwind.
#
# Unlike AWS, the Databricks side is not created here: the Terraform
# provider's databricks_mws_log_delivery is AWS-only. Upwind creates the
# storage and log delivery configurations through the account API, with the
# service principal the customer registered, once the outputs are pasted in.
#
# With existing_bucket_name, a Databricks log delivery already writes to a bucket
# of the customer's: no bucket is created and Databricks is granted nothing. The
# notification is added to that bucket, additively (a bucket keeps its other
# notifications), and Upwind uses the delivery that is there rather than adding
# its own.

data "google_project" "current" {
  project_id = var.project_id
}

# The Google-managed agent that publishes bucket notifications on the project's
# behalf; it needs publisher on the topic.
data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

resource "random_string" "suffix" {
  count = var.resource_suffix == "" ? 1 : 0

  length  = 6
  upper   = false
  special = false
}

locals {
  suffix         = var.resource_suffix != "" ? var.resource_suffix : random_string.suffix[0].result
  project_number = data.google_project.current.number

  use_existing_bucket = var.existing_bucket_name != ""

  bucket_name = local.use_existing_bucket ? var.existing_bucket_name : (
    var.bucket_name != "" ? var.bucket_name : "${var.resource_name_prefix}-${local.suffix}"
  )
  # Read from the bucket resource when the module creates it, so whatever
  # names the bucket through this waits for it.
  bucket_ref      = local.use_existing_bucket ? var.existing_bucket_name : google_storage_bucket.audit_logs[0].name
  bucket_location = local.use_existing_bucket ? data.google_storage_bucket.existing[0].location : google_storage_bucket.audit_logs[0].location

  topic_name        = var.topic_name != "" ? var.topic_name : "${var.resource_name_prefix}-${local.suffix}"
  subscription_name = var.subscription_name != "" ? var.subscription_name : "${var.resource_name_prefix}-${local.suffix}"

  # Objects Databricks writes all sit under the prefix; the notification filter
  # is scoped to it so a shared bucket does not flood the subscription.
  object_prefix = "${var.delivery_path_prefix}/"

  # GCP labels: lower case, no uppercase keys or values.
  common_labels = merge(
    var.include_common_labels ? {
      managed_by  = "terraform"
      environment = lower(var.environment)
    } : {},
    var.additional_labels,
  )

  required_apis = [
    "pubsub.googleapis.com",
    "storage.googleapis.com",
  ]
}

# The existing bucket, checked to be in project_id: the notification is
# published by that project's GCS service agent, granted on the topic below.
data "google_storage_bucket" "existing" {
  count = local.use_existing_bucket ? 1 : 0
  name  = var.existing_bucket_name
}

resource "google_project_service" "required" {
  for_each = var.enable_apis ? toset(local.required_apis) : toset([])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

#
# Bucket
#

# Multi-region Standard with uniform access, as Databricks documents.
# Versioning stays off: Databricks rewrites files in place, so versioning would
# keep every intermediate copy.
resource "google_storage_bucket" "audit_logs" {
  count = local.use_existing_bucket ? 0 : 1

  project                     = var.project_id
  name                        = local.bucket_name
  location                    = var.bucket_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.bucket_force_destroy
  labels                      = local.common_labels

  versioning {
    enabled = false
  }

  # Delivered files are only needed until Upwind has read them, minutes after
  # delivery; expiring them keeps storage, the one cost that grows, flat.
  dynamic "lifecycle_rule" {
    for_each = var.log_retention_days > 0 ? [1] : []
    content {
      condition {
        age            = var.log_retention_days
        matches_prefix = [local.object_prefix]
      }
      action {
        type = "Delete"
      }
    }
  }

  depends_on = [google_project_service.required]
}

# Storage Admin on the bucket is the grant Databricks documents; it needs to
# write and list the delivered files.
resource "google_storage_bucket_iam_member" "databricks_delivery" {
  count = local.use_existing_bucket ? 0 : 1

  bucket = google_storage_bucket.audit_logs[0].name
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.databricks_log_delivery_service_account}"
}

#
# Topic, subscription and notification
#

resource "google_pubsub_topic" "audit_logs" {
  project = var.project_id
  name    = local.topic_name
  labels  = local.common_labels

  depends_on = [google_project_service.required]
}

resource "google_pubsub_topic_iam_member" "gcs_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.audit_logs.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

# Databricks overwrites files in place, so a notification means "this object
# may have grown", not "here is a new batch". Upwind keeps a per-object offset.
# On an existing bucket this is one more notification configuration next to the
# ones it has, scoped to the delivery prefix; destroy removes only this one.
resource "google_storage_notification" "audit_logs" {
  bucket             = local.bucket_ref
  topic              = google_pubsub_topic.audit_logs.id
  payload_format     = "JSON_API_V1"
  event_types        = ["OBJECT_FINALIZE"]
  object_name_prefix = local.object_prefix

  depends_on = [google_pubsub_topic_iam_member.gcs_publisher]

  lifecycle {
    precondition {
      condition     = !local.use_existing_bucket || tostring(data.google_storage_bucket.existing[0].project_number) == tostring(local.project_number)
      error_message = "The bucket in existing_bucket_name is in another project than project_id. Set project_id to the bucket's project: its GCS service agent publishes the notifications."
    }
  }
}

resource "google_pubsub_subscription" "audit_logs" {
  project                    = var.project_id
  name                       = local.subscription_name
  topic                      = google_pubsub_topic.audit_logs.id
  ack_deadline_seconds       = var.subscription_ack_deadline_seconds
  message_retention_duration = "${var.subscription_message_retention_seconds}s"
  labels                     = local.common_labels

  # Never let an idle subscription expire; Upwind may be paused for a while.
  expiration_policy {
    ttl = ""
  }
}
