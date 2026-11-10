# Upwind builds every name from the project ID and the resource suffix, so
# nothing needs to be pasted back:
#
#   bucket          upwind-databricks-audit-logs-<suffix>, objects under audit-logs/
#   subscription    projects/<project_id>/subscriptions/upwind-databricks-audit-logs-<suffix>
output "upwind_delivery_target" {
  description = "What Upwind reads, for reference."
  value       = module.gcp_databricks_audit_logs.upwind_delivery_target
}
