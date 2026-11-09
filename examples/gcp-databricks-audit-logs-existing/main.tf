provider "google" {
  project = var.project_id
}

# A Databricks log delivery already writes to the bucket: no bucket or
# delivery is created and Databricks' service account is granted nothing. The
# module adds a Pub/Sub notification to the bucket, keeping its others.
#
# Upwind reads the logs through your Upwind GCP onboarding: apply it with
# enable_dataevents = true, on a scope that includes project_id. This module
# creates no identity or grant for Upwind.
module "gcp_databricks_audit_logs" {
  source = "../../modules/gcp-databricks-audit-logs"

  project_id      = var.project_id
  resource_suffix = var.upwind_resource_suffix

  existing_bucket_name = var.existing_bucket_name
  delivery_path_prefix = var.delivery_path_prefix
}
