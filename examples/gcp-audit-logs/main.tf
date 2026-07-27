# Organization-level example (default).
# Streams GCP Cloud Audit Logs to Upwind via a Log Router sink, Pub/Sub, and
# Workload Identity Federation.

module "gcp_audit_logs" {
  source = "../../modules/gcp-audit-logs"

  gcp_organization_id        = "123456789012"
  infrastructure_project_id  = "my-gcp-project"
  upwind_management_sa_email = "upwind-mgmt-xxxxx@your-project.iam.gserviceaccount.com"

  integration_type = "ORGANIZATION"

  enable_admin_activity_logs = true
  enable_system_event_logs   = false
}
