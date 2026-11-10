provider "google" {
  project = var.project_id
}

# Upwind reads the logs through your Upwind GCP onboarding: apply it with
# enable_dataevents = true, on a scope that includes project_id. This module
# creates no identity or grant for Upwind.
module "gcp_databricks_audit_logs" {
  source = "../../modules/gcp-databricks-audit-logs"

  project_id      = var.project_id
  resource_suffix = var.upwind_resource_suffix
}
