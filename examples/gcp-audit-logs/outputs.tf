output "upwind_runner_sa_email" {
  description = "Runner SA email"
  value       = module.gcp_audit_logs.upwind_runner_sa_email
}

output "upwind_pubsub_topic_id" {
  description = "Fully-qualified Pub/Sub topic ID"
  value       = module.gcp_audit_logs.upwind_pubsub_topic_id
}

output "upwind_log_sink_writer_identities" {
  description = "Cloud Logging SAs that publish to the topic — one per sink"
  value       = module.gcp_audit_logs.upwind_log_sink_writer_identities
}
