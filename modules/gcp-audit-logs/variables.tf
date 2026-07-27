#region Variables

variable "gcp_organization_id" {
  description = "The GCP organization ID. Required for all integration types — used to generate unique resource name suffixes and, for ORGANIZATION type, to create the org-level log sink and IAM role."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.gcp_organization_id))
    error_message = "The GCP organization ID must be numeric."
  }
}

variable "infrastructure_project_id" {
  description = "The GCP project ID where all integration resources (Pub/Sub, Service Account, WIF pool, Secret Manager secret) are provisioned."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.infrastructure_project_id))
    error_message = "The GCP project ID must be 6-30 characters, lowercase letters, numbers, or hyphens, must start with a letter, and cannot end with a hyphen."
  }
}

variable "enable_admin_activity_logs" {
  description = "Capture Admin Activity audit logs (records admin operations such as creating/modifying resources). Cannot be disabled in GCP — this variable controls whether the sink routes them."
  type        = bool
  default     = true
}

variable "enable_data_access_logs" {
  description = "Capture Data Access audit logs (records API calls that read/write user data) and Google Workspace login events (login.googleapis.com). Disabled by default — generates significant volume and incurs GCP charges. Must also be enabled in GCP org Audit Logs settings. Google Workspace login events additionally require data sharing enabled in the Google Admin console."
  type        = bool
  default     = false
}

variable "enable_system_event_logs" {
  description = "Capture System Event audit logs (records GCP system actions, not user-initiated). Cannot be disabled in GCP — this variable controls whether the sink routes them."
  type        = bool
  default     = false
}

variable "enable_policy_denied_logs" {
  description = "Capture Policy Denied audit logs (records when a principal is denied access due to a security policy violation, e.g. VPC Service Controls). Incurs GCP charges."
  type        = bool
  default     = false
}

variable "included_project_ids" {
  description = "If set, only audit logs from these GCP project IDs are captured. Applies to ORGANIZATION and FOLDER integration types. Mutually exclusive with excluded_project_ids."
  type        = list(string)
  default     = []
}

variable "excluded_project_ids" {
  description = "GCP project IDs to exclude from the sink. All other projects are captured. Applies to ORGANIZATION and FOLDER integration types. Mutually exclusive with included_project_ids."
  type        = list(string)
  default     = []
}

variable "folder_log_sources" {
  description = "Folder IDs whose folder-level audit log entries should be captured in the org-level sink (e.g. IAM changes on the folder itself). ORGANIZATION type only. Requires included_project_ids to be set."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for f in var.folder_log_sources : can(regex("^[0-9]+$", f))])
    error_message = "All entries in folder_log_sources must be numeric GCP folder IDs (e.g. \"123456789012\")."
  }
}

variable "integration_type" {
  description = "Integration scope. ORGANIZATION creates an org-level sink, FOLDER creates a folder-level sink for folder_id, PROJECT creates one sink per entry in monitored_project_ids. Use included_project_ids or excluded_project_ids to filter projects (ORGANIZATION and FOLDER only)."
  type        = string
  default     = "ORGANIZATION"

  validation {
    condition     = contains(["ORGANIZATION", "FOLDER", "PROJECT"], var.integration_type)
    error_message = "integration_type must be one of: ORGANIZATION, FOLDER, PROJECT."
  }
}

variable "folder_id" {
  description = "The GCP folder ID to create the log sink for. Required when integration_type is FOLDER. Use included_project_ids or excluded_project_ids to filter projects within the folder."
  type        = string
  default     = ""

  validation {
    condition     = var.folder_id == "" || can(regex("^[0-9]+$", var.folder_id))
    error_message = "folder_id must be a numeric GCP folder ID (e.g. \"123456789012\")."
  }
}

variable "monitored_project_ids" {
  description = "Project IDs to create log sinks for. Required when integration_type is PROJECT. Each project gets its own sink routing to the same Pub/Sub topic."
  type        = list(string)
  default     = []
}

variable "log_sink_name" {
  description = "The name of the log sink (e.g., 'org-all-audit-sink'). Must be unique within the organization."
  type        = string
  default     = "upwind-gcp-audit-logs-sink"
}

variable "log_sink_description" {
  description = "An optional description for your log sink."
  type        = string
  default     = "Upwind audit logs sink."
}

variable "pubsub_topic_name" {
  description = "The name of the Pub/Sub topic to create."
  type        = string
  default     = "upwind-gcp-audit-logs-topic"
}

variable "pubsub_subscription_name" {
  description = "The name of the Pub/Sub subscription to create."
  type        = string
  default     = "upwind-gcp-audit-logs-subscription"
}

variable "log_sink_exclusions" {
  description = "Additional named exclusion filters applied to the log sink, merged with the default GKE and sys-project exclusions. Matching log entries are dropped before reaching Pub/Sub. Do not reuse the reserved names: exclude-gke-k8s, exclude-sys-projects."
  type = list(object({
    name        = string
    description = optional(string)
    filter      = string
  }))
  default = []
}

variable "labels" {
  description = "Additional labels to apply to the Pub/Sub topic, subscription, and Secret Manager secret. Keys and values must be lowercase. The label upwind-component=gcp-audit-logs is always applied and cannot be overridden."
  type        = map(string)
  default     = {}
}

variable "message_retention_duration" {
  description = "How long Pub/Sub retains messages on the topic and unacknowledged messages on the subscription. If Upwind's service is down longer than this window, older messages are discarded. GCP range: 600s (10 min) to 604800s (7 days)."
  type        = string
  default     = "21600s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.message_retention_duration))
    error_message = "message_retention_duration must be a number of seconds followed by 's' (e.g., '21600s')."
  }
}

variable "upwind_trusted_account_id" {
  description = "Upwind's AWS account ID that the WIF pool will trust. Defaults to Upwind's production account."
  type        = string
  default     = "340457201789"
}

variable "resource_suffix" {
  description = "Suffix appended to all resource names to avoid conflicts when running the module more than once in the same project. Applied to sink, Pub/Sub, Secret Manager, SA, WIF pool, and IAM roles. Max 6 lowercase alphanumeric characters."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,6}$", var.resource_suffix))
    error_message = "The resource suffix must be lowercase alphanumeric and cannot exceed 6 characters."
  }
}

variable "upwind_wif_secret" {
  description = "Name of the Secret Manager secret where the WIF credentials will be stored."
  type        = string
  default     = "upwind-audit-logs-wif-secret"
}

variable "upwind_management_sa_email" {
  description = "Upwind management service account email provided during setup. Granted secretAccessor on the WIF secret."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.iam\\.gserviceaccount\\.com$", var.upwind_management_sa_email))
    error_message = "upwind_management_sa_email must be a valid GCP service account email (e.g., name@project.iam.gserviceaccount.com)."
  }
}

variable "secret_replication_locations" {
  description = "Regions for user-managed Secret Manager replication of the WIF credentials secret. Leave empty for automatic (global) replication. Set this only when an org policy (e.g. constraints/gcp.resourceLocations) blocks global secrets — replication is immutable, so this must be set before the secret is first created and cannot be changed on an already-deployed secret without destroying and recreating it."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.secret_replication_locations : can(regex("^[a-z]+-[a-z0-9]+$", r))])
    error_message = "Each replication location must be a valid GCP region (e.g. us-central1, europe-west1)."
  }
}
#endregion
