output "bucket_name" {
  description = "Bucket Databricks delivers audit logs into: the one created, or existing_bucket_name."
  value       = local.bucket_ref
}

output "delivery_path_prefix" {
  description = "Object name prefix the files land under."
  value       = var.delivery_path_prefix
}

output "topic_id" {
  description = "Pub/Sub topic receiving bucket notifications."
  value       = google_pubsub_topic.audit_logs.id
}

output "subscription_id" {
  description = "Pub/Sub subscription Upwind pulls."
  value       = google_pubsub_subscription.audit_logs.id
}

# Everything the Upwind console asks for after the apply, in one object.
output "upwind_delivery_target" {
  description = "Delivery target descriptor to paste into the Upwind console."
  value = {
    type             = "gcp_gcs_pubsub"
    databricks_cloud = "gcp"
    region           = local.bucket_location
    project_id       = var.project_id
    subscription     = google_pubsub_subscription.audit_logs.id
    bucket           = local.bucket_ref
    prefix           = var.delivery_path_prefix
  }
}
