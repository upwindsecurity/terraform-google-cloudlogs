# The bucket and prefix are the existing delivery's, given to the Upwind
# console. Upwind builds the subscription name from the project ID and the
# suffix: projects/<project_id>/subscriptions/upwind-databricks-audit-logs-<suffix>
output "upwind_delivery_target" {
  description = "What Upwind reads, for reference."
  value       = module.gcp_databricks_audit_logs.upwind_delivery_target
}
