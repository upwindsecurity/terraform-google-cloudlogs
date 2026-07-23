#region IAM Service Accounts

resource "google_service_account" "upwind_audit_logs_runner_sa" {
  account_id   = "audit-logs-runner-${local.resource_suffix_hyphen}"
  display_name = "Audit Logs Runner Service Account"
  project      = var.infrastructure_project_id
  description  = "Upwind impersonates this SA via WIF to pull audit logs from Pub/Sub"

  depends_on = [google_project_service.required_apis]

  lifecycle {
    precondition {
      # "audit-logs-runner-" prefix is 18 chars; GCP SA account_id limit is 30 chars.
      condition     = length(local.resource_suffix_hyphen) <= 12
      error_message = "Combined org_id + resource_suffix (resource_suffix_hyphen) must be ≤12 characters so the service account ID stays within GCP's 30-character limit."
    }
  }
}
#endregion
