#region Outputs

output "upwind_log_sink_ids" {
  description = "The full resource IDs of all created log sinks (org, folder, or project depending on integration_type)."
  value = concat(
    [for s in google_logging_organization_sink.audit_logs_sink : s.id],
    [for s in google_logging_folder_sink.audit_logs_sink : s.id],
    [for s in google_logging_project_sink.audit_logs_sink : s.id],
  )
}

output "upwind_log_sink_writer_identities" {
  description = "The Cloud Logging service account emails that write logs to the Pub/Sub topic. One entry per sink. Publisher bindings are managed by this module."
  value       = local.writer_identities
}

output "upwind_pubsub_topic_name" {
  description = "The name of the Pub/Sub topic used for audit logs"
  value       = google_pubsub_topic.audit_logs_topic.name
}

output "upwind_pubsub_topic_id" {
  description = "The fully qualified identifier of the Pub/Sub topic"
  value       = google_pubsub_topic.audit_logs_topic.id
}

output "upwind_pubsub_subscription_name" {
  description = "The name of the Pub/Sub subscription for audit logs"
  value       = google_pubsub_subscription.audit_logs_subscription.name
}

output "upwind_runner_sa_email" {
  description = "Email of the runner service account — Upwind impersonates this SA via WIF to pull from Pub/Sub"
  value       = google_service_account.upwind_audit_logs_runner_sa.email
}

output "upwind_runner_sa_name" {
  description = "The fully qualified name of the service account"
  value       = google_service_account.upwind_audit_logs_runner_sa.name
}


output "upwind_wif_secret" {
  description = "The name of the Secret Manager secret for Workload Identity Federation configuration"
  value       = google_secret_manager_secret.upwind_wif_secret.secret_id
}

output "upwind_wif_pool_id" {
  description = "The ID of the GCP Workload Identity Pool (used in the WIF audience URL)."
  value       = google_iam_workload_identity_pool.upwind_wif_pool.workload_identity_pool_id
}

output "upwind_wif_provider_id" {
  description = "The ID of the Workload Identity Pool Provider (AWS) (used in the WIF audience URL)."
  value       = google_iam_workload_identity_pool_provider.upwind_aws_provider.workload_identity_pool_provider_id
}

output "upwind_wif_audience" {
  description = "The full audience string for the WIF JSON configuration file."
  value       = "//iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.upwind_wif_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.upwind_aws_provider.workload_identity_pool_provider_id}"
}

output "upwind_wif_sa_impersonation_url" {
  description = "The service account impersonation URL for the WIF JSON configuration file."
  value       = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.upwind_audit_logs_runner_sa.email}:generateAccessToken"
}

output "upwind_project_number" {
  description = "The numeric project number of the infrastructure project."
  value       = data.google_project.infrastructure_project.number
}

#endregion

