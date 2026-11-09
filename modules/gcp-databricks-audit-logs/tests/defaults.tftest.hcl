mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
  mock_data "google_storage_project_service_account" {
    defaults = {
      email_address = "service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_storage_bucket" {
    defaults = {
      location = "US"
    }
  }
  mock_data "google_storage_bucket" {
    defaults = {
      location                    = "EU"
      project_number              = 123456789012
      uniform_bucket_level_access = true
    }
  }
  mock_resource "google_pubsub_topic" {
    defaults = {
      id = "projects/acme-project/topics/upwind-databricks-audit-logs-abc123"
    }
  }
  mock_resource "google_pubsub_subscription" {
    defaults = {
      id = "projects/acme-project/subscriptions/upwind-databricks-audit-logs-abc123"
    }
  }
}

mock_provider "random" {
  mock_resource "random_string" {
    defaults = {
      result = "abc123"
    }
  }
}

variables {
  project_id = "acme-project"
}

run "defaults" {
  command = apply

  assert {
    condition     = google_storage_bucket.audit_logs[0].name == "upwind-databricks-audit-logs-abc123"
    error_message = "Bucket name must default to prefix and suffix"
  }

  assert {
    condition     = google_storage_bucket.audit_logs[0].location == "US" && google_storage_bucket.audit_logs[0].uniform_bucket_level_access && google_storage_bucket.audit_logs[0].public_access_prevention == "enforced"
    error_message = "Bucket must be multi-region, uniform access and never public, as Databricks documents"
  }

  assert {
    condition     = google_storage_bucket_iam_member.databricks_delivery[0].role == "roles/storage.admin" && google_storage_bucket_iam_member.databricks_delivery[0].member == "serviceAccount:log-delivery@databricks-prod-master.iam.gserviceaccount.com"
    error_message = "Databricks' log-delivery service account must get Storage Admin on the bucket"
  }

  assert {
    condition     = google_storage_notification.audit_logs.object_name_prefix == "audit-logs/" && google_storage_notification.audit_logs.event_types == toset(["OBJECT_FINALIZE"])
    error_message = "Notifications must be OBJECT_FINALIZE scoped to the delivery prefix"
  }

  assert {
    condition     = google_pubsub_topic_iam_member.gcs_publisher.member == "serviceAccount:service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    error_message = "The project's GCS service agent must be able to publish to the topic"
  }

  assert {
    condition     = length(google_project_service.required) == 2
    error_message = "Required APIs must be enabled by default"
  }

  assert {
    condition     = google_storage_notification.audit_logs.bucket == "upwind-databricks-audit-logs-abc123"
    error_message = "A new delivery's notification must be on the bucket the module creates"
  }

  assert {
    condition     = length(data.google_storage_bucket.existing) == 0
    error_message = "A new delivery must not look up an existing bucket"
  }

  # Upwind reads through the Upwind GCP onboarding (enable_dataevents), not an
  # identity of this module's.
  assert {
    condition     = length(google_storage_bucket_iam_member.databricks_delivery) == 1
    error_message = "Databricks' delivery must be the only grant on the bucket"
  }
}

run "overrides" {
  command = apply

  variables {
    bucket_name          = "acme-databricks-audit"
    delivery_path_prefix = "logs/databricks"
    enable_apis          = false
  }

  assert {
    condition     = google_storage_bucket.audit_logs[0].name == "acme-databricks-audit"
    error_message = "Bucket name override must win"
  }

  assert {
    condition     = google_storage_notification.audit_logs.object_name_prefix == "logs/databricks/"
    error_message = "Notification filter must follow the prefix"
  }

  assert {
    condition     = length(google_project_service.required) == 0
    error_message = "enable_apis = false must leave the project's APIs alone"
  }
}

run "rejects_bad_prefix" {
  command = plan

  variables {
    delivery_path_prefix = "/audit logs/"
  }

  expect_failures = [var.delivery_path_prefix]
}

run "delivery_target_contract" {
  command = apply

  assert {
    condition     = output.upwind_delivery_target.type == "gcp_gcs_pubsub" && output.upwind_delivery_target.databricks_cloud == "gcp"
    error_message = "The delivery target must identify itself as the GCP GCS + Pub/Sub shape"
  }

  assert {
    condition     = alltrue([for k in ["region", "project_id", "subscription", "bucket", "prefix"] : contains(keys(output.upwind_delivery_target), k)])
    error_message = "The delivery target must carry every key the console contract lists for gcp_gcs_pubsub"
  }
}

# The console injects the suffix, so Upwind knows every name before the apply
# and never needs the outputs.
run "injected_suffix" {
  command = apply

  variables {
    resource_suffix = "k3x9q2"
  }

  assert {
    condition     = length(random_string.suffix) == 0
    error_message = "An injected suffix must replace the random one"
  }

  assert {
    condition     = google_storage_bucket.audit_logs[0].name == "upwind-databricks-audit-logs-k3x9q2" && google_pubsub_subscription.audit_logs.name == "upwind-databricks-audit-logs-k3x9q2"
    error_message = "Bucket and subscription must be named from the injected suffix"
  }
}

run "retention" {
  command = apply

  assert {
    condition     = length(google_storage_bucket.audit_logs[0].lifecycle_rule) == 1 && one(google_storage_bucket.audit_logs[0].lifecycle_rule[0].condition).age == 7 && one(google_storage_bucket.audit_logs[0].lifecycle_rule[0].action).type == "Delete"
    error_message = "Delivered files must be deleted after 7 days by default"
  }
}

run "retention_disabled" {
  command = apply

  variables {
    log_retention_days = 0
  }

  assert {
    condition     = length(google_storage_bucket.audit_logs[0].lifecycle_rule) == 0
    error_message = "log_retention_days = 0 must keep files forever"
  }
}

# A delivery that already writes to a bucket of the customer's: no bucket is
# created and Databricks is granted nothing; the notification is added to that
# bucket, under the delivery's prefix, and nothing is granted on it.
run "existing_delivery" {
  command = apply

  variables {
    existing_bucket_name = "acme-dbx-audit-logs"
    delivery_path_prefix = "databricks/audit"
  }

  assert {
    condition     = length(google_storage_bucket.audit_logs) == 0 && length(google_storage_bucket_iam_member.databricks_delivery) == 0
    error_message = "An existing delivery must create no bucket and grant Databricks nothing"
  }

  assert {
    condition     = google_storage_notification.audit_logs.bucket == "acme-dbx-audit-logs" && google_storage_notification.audit_logs.object_name_prefix == "databricks/audit/"
    error_message = "The notification must be added to the existing bucket, under its delivery prefix"
  }

  assert {
    condition     = google_pubsub_subscription.audit_logs.name == "upwind-databricks-audit-logs-abc123"
    error_message = "The subscription keeps the name Upwind derives from the suffix"
  }

  assert {
    condition     = output.bucket_name == "acme-dbx-audit-logs" && output.upwind_delivery_target.bucket == "acme-dbx-audit-logs" && output.upwind_delivery_target.prefix == "databricks/audit" && output.upwind_delivery_target.region == "EU"
    error_message = "The outputs must name the existing bucket, its prefix and its location"
  }
}

# The notification is published by the bucket's project's GCS service agent,
# which is granted on the topic in project_id only.
run "rejects_existing_bucket_in_another_project" {
  command = plan

  variables {
    existing_bucket_name = "acme-dbx-audit-logs"
  }

  override_data {
    target = data.google_storage_bucket.existing[0]
    values = {
      project_number              = 999999999999
      uniform_bucket_level_access = true
    }
  }

  expect_failures = [google_storage_notification.audit_logs]
}

run "rejects_bad_existing_bucket_name" {
  command = plan

  variables {
    existing_bucket_name = "gs://acme-dbx-audit-logs"
  }

  expect_failures = [var.existing_bucket_name]
}
