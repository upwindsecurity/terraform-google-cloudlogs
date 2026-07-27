#region IAM

#region Runner SA → Pub/Sub topic viewer binding
# Grants pubsub.topics.get scoped to this specific topic only.
# Using topic-level IAM avoids creating a project custom role — GCP enforces a hard limit of
# 300 custom roles per project, which is easily exhausted in shared environments.
resource "google_pubsub_topic_iam_member" "runner_sa_topic_binding" {
  topic   = google_pubsub_topic.audit_logs_topic.name
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.upwind_audit_logs_runner_sa.email}"
  project = var.infrastructure_project_id
}
#endregion

#region Sink reader bindings (logging.sinks.get via roles/logging.viewer)
# roles/logging.viewer is a predefined GCP role that includes logging.sinks.get.
# Using a predefined role avoids creating an org-level custom role, which would require
# roles/iam.organizationRoleAdmin from the customer running Terraform.
# Trade-off: roles/logging.viewer grants broader read-only logging access beyond just
# logging.sinks.get — this is intentional to eliminate the org admin requirement.
resource "google_organization_iam_member" "log_sink_reader_binding" {
  count  = var.integration_type == "ORGANIZATION" ? 1 : 0
  org_id = var.gcp_organization_id
  role   = "roles/logging.viewer"
  member = "serviceAccount:${google_service_account.upwind_audit_logs_runner_sa.email}"
}

resource "google_folder_iam_member" "log_sink_reader_binding" {
  count  = var.integration_type == "FOLDER" ? 1 : 0
  folder = "folders/${var.folder_id}"
  role   = "roles/logging.viewer"
  member = "serviceAccount:${google_service_account.upwind_audit_logs_runner_sa.email}"
}

# PROJECT: bind at each monitored project scope.
resource "google_project_iam_member" "log_sink_reader_binding" {
  for_each = var.integration_type == "PROJECT" ? toset(var.monitored_project_ids) : toset([])
  project  = each.value
  role     = "roles/logging.viewer"
  member   = "serviceAccount:${google_service_account.upwind_audit_logs_runner_sa.email}"
}
#endregion

#region Log sink → Pub/Sub topic publisher binding
# Authoritative binding — this topic is created and owned by this module so no
# other publisher should exist. iam_binding avoids the plan-time error caused by
# using unknown writer_identity values as for_each keys.
resource "google_pubsub_topic_iam_binding" "log_sink_publisher_binding" {
  topic   = google_pubsub_topic.audit_logs_topic.name
  role    = "roles/pubsub.publisher"
  members = local.writer_identities
  project = var.infrastructure_project_id
}
#endregion

#region Runner SA → subscription subscriber binding
resource "google_pubsub_subscription_iam_member" "runner_sa_subscription_binding" {
  subscription = google_pubsub_subscription.audit_logs_subscription.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.upwind_audit_logs_runner_sa.email}"
  project      = var.infrastructure_project_id
}
#endregion

#region Runner SA → Cloud Monitoring viewer binding
# Grants monitoring.timeSeries.list on the infrastructure project so Upwind can read
# Pub/Sub backlog metrics for the subscription created by this module
# (subscription/num_undelivered_messages, subscription/oldest_unacked_message_age).
# Project-level because Cloud Monitoring has no resource-level IAM for time series reads.
resource "google_project_iam_member" "runner_sa_monitoring_viewer_binding" {
  project = var.infrastructure_project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.upwind_audit_logs_runner_sa.email}"
}
#endregion

#region Secret Manager: Upwind's management SA reads the WIF secret
# Upwind's management SA needs secretAccessor to read the WIF credentials JSON
# once during create-integration and store it in Upwind's database.
resource "google_secret_manager_secret_iam_member" "upwind_sa_secret_binding" {
  secret_id = google_secret_manager_secret.upwind_wif_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.upwind_management_sa_email}"
}
#endregion

#region IAM propagation wait
# GCP IAM bindings are eventually consistent — new bindings typically take up to
# 2 minutes to propagate globally. This wait ensures the WIF token exchange and
# sink reader check succeed when the console calls test-connectivity immediately
# after apply. Only applies on resource creation, not on updates or re-applies.
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    google_iam_workload_identity_pool_provider.upwind_aws_provider,
    google_service_account_iam_member.audit_logs_workload_identity,
    google_pubsub_topic_iam_member.runner_sa_topic_binding,
    google_pubsub_subscription_iam_member.runner_sa_subscription_binding,
    google_organization_iam_member.log_sink_reader_binding,
    google_folder_iam_member.log_sink_reader_binding,
    google_project_iam_member.log_sink_reader_binding,
    google_pubsub_topic_iam_binding.log_sink_publisher_binding,
    google_secret_manager_secret_iam_member.upwind_sa_secret_binding,
  ]
  create_duration = "120s"
}
#endregion

#endregion
