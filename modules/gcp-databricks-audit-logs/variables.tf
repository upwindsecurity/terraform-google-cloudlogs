variable "project_id" {
  description = "GCP project that owns the bucket, topic and subscription. Upwind reads them through the Upwind GCP onboarding, so the project must be in its onboarded scope with enable_dataevents = true."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a GCP project ID: 6-30 lower-case letters, digits or hyphens, starting with a letter."
  }
}

variable "databricks_log_delivery_service_account" {
  description = "Databricks' service account that writes audit logs on GCP. Granted Storage Admin on the bucket, as Databricks documents. Not used with existing_bucket_name: the delivery that is there already writes."
  type        = string
  default     = "log-delivery@databricks-prod-master.iam.gserviceaccount.com"
}

variable "resource_name_prefix" {
  description = "Prefix for the bucket, topic and subscription names. Lower case, as GCS bucket names require."
  type        = string
  default     = "upwind-databricks-audit-logs"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,40}$", var.resource_name_prefix))
    error_message = "resource_name_prefix must be 1-41 lower-case letters, digits or hyphens, starting with a letter."
  }
}

variable "existing_bucket_name" {
  description = "Name of an existing bucket a Databricks audit log delivery already writes to. Set it to read from that delivery instead of creating a bucket: no bucket is created, Databricks' service account is granted nothing, and Upwind uses the delivery that is there instead of adding its own. The module adds a Pub/Sub notification to the bucket (its other notifications are kept) and grants nothing on it. The bucket must be in project_id. Set delivery_path_prefix to the delivery's prefix."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_bucket_name == "" || (can(regex("^[a-z0-9][a-z0-9_.-]*[a-z0-9]$", var.existing_bucket_name)) && length(var.existing_bucket_name) >= 3 && length(var.existing_bucket_name) <= 63)
    error_message = "existing_bucket_name must be a bucket name: 3-63 characters of lower-case letters, digits, dots, underscores and hyphens, starting and ending with a letter or digit."
  }
}

variable "bucket_name" {
  description = "Name of the GCS bucket to create for delivered audit logs. Empty generates <prefix>-<suffix>. Ignored with existing_bucket_name."
  type        = string
  default     = ""

  validation {
    condition     = var.bucket_name == "" || (can(regex("^[a-z0-9][a-z0-9_.-]*[a-z0-9]$", var.bucket_name)) && length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63)
    error_message = "bucket_name must be 3-63 characters of lower-case letters, digits, dots, underscores and hyphens, starting and ending with a letter or digit."
  }
}

variable "bucket_location" {
  description = "Bucket location. Databricks documents a multi-region bucket (US, EU or ASIA). Ignored with existing_bucket_name."
  type        = string
  default     = "US"
}

variable "bucket_force_destroy" {
  description = "Delete the bucket on destroy even when it still holds audit log files. Use with care. Ignored with existing_bucket_name: the module never deletes a bucket it did not create."
  type        = bool
  default     = false
}

variable "delivery_path_prefix" {
  description = "Object name prefix Databricks writes under. Files land at <prefix>/workspaceId=<id>/date=<yyyy-mm-dd>/auditlogs_<id>.json. No leading or trailing slash, no spaces. With existing_bucket_name: the prefix of the delivery already writing to it."
  type        = string
  default     = "audit-logs"

  validation {
    condition     = var.delivery_path_prefix != "" && !startswith(var.delivery_path_prefix, "/") && !endswith(var.delivery_path_prefix, "/") && !strcontains(var.delivery_path_prefix, " ")
    error_message = "delivery_path_prefix must be non-empty, contain no spaces and not start or end with a slash."
  }
}

variable "topic_name" {
  description = "Name of the Pub/Sub topic that receives bucket notifications. Empty generates <prefix>-<suffix>."
  type        = string
  default     = ""
}

variable "subscription_name" {
  description = "Name of the Pub/Sub subscription Upwind pulls. Empty generates <prefix>-<suffix>."
  type        = string
  default     = ""
}

variable "subscription_message_retention_seconds" {
  description = "How long an unacked notification stays on the subscription. Covers an Upwind outage without losing pointers to files."
  type        = number
  default     = 345600 # 4 days

  validation {
    condition     = var.subscription_message_retention_seconds >= 600 && var.subscription_message_retention_seconds <= 604800
    error_message = "subscription_message_retention_seconds must be between 600 and 604800."
  }
}

variable "subscription_ack_deadline_seconds" {
  description = "How long a notification is hidden after Upwind pulls it. Must exceed the time to read and publish one file."
  type        = number
  default     = 300

  validation {
    condition     = var.subscription_ack_deadline_seconds >= 10 && var.subscription_ack_deadline_seconds <= 600
    error_message = "subscription_ack_deadline_seconds must be between 10 and 600."
  }
}

variable "enable_apis" {
  description = "Enable the Pub/Sub and Storage APIs on the project. They are left enabled on destroy."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment label applied to every labelled resource."
  type        = string
  default     = "production"
}

variable "include_common_labels" {
  description = "Apply the managed_by and environment labels."
  type        = bool
  default     = true
}

variable "additional_labels" {
  description = "Extra labels applied to every labelled resource."
  type        = map(string)
  default     = {}
}

variable "resource_suffix" {
  description = "Suffix for every name this module creates. The Upwind console sets it, so Upwind knows the names without reading the outputs. Empty generates a random one."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,6}$", var.resource_suffix))
    error_message = "resource_suffix must be up to 6 lower-case letters or digits."
  }
}

variable "log_retention_days" {
  description = "Days a delivered file is kept before it is deleted. Upwind reads files within minutes of delivery; 0 keeps them forever. Ignored with existing_bucket_name: the existing bucket's lifecycle is left alone."
  type        = number
  default     = 7

  validation {
    condition     = var.log_retention_days >= 0 && floor(var.log_retention_days) == var.log_retention_days
    error_message = "log_retention_days must be a whole number of days, 0 or more."
  }
}
