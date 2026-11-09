variable "project_id" {
  description = "GCP project that owns the bucket, topic and subscription. It must be in the scope of your Upwind GCP onboarding, applied with enable_dataevents = true."
  type        = string
}

variable "upwind_resource_suffix" {
  description = "Resource suffix shown in the Upwind console for this integration. Upwind derives the bucket and subscription names from it."
  type        = string
}
