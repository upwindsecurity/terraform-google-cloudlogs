variable "project_id" {
  description = "GCP project that owns the bucket, topic and subscription. It must be in the scope of your Upwind GCP onboarding, applied with enable_dataevents = true."
  type        = string
}

variable "upwind_resource_suffix" {
  description = "Resource suffix shown in the Upwind console for this integration. Upwind derives the subscription name from it."
  type        = string
}

variable "existing_bucket_name" {
  description = "Bucket an existing Databricks audit log delivery writes to. It must be in project_id."
  type        = string
}

variable "delivery_path_prefix" {
  description = "Object name prefix the existing delivery writes under (its delivery path prefix in Databricks)."
  type        = string
}
