# gcp-audit-logs

Provisions all GCP infrastructure required for Upwind to ingest GCP Audit Logs in real time.

---

## Integration types

### ORGANIZATION (default)

A single org-level sink routes logs from every project in the organization to Pub/Sub.

**When to use:** The customer wants full org coverage.

**Project filtering (optional):**
- `included_project_ids` — only capture logs from these project IDs
- `excluded_project_ids` — capture all projects except these
- Neither — capture all projects

```hcl
module "gcp_audit_logs" {
  source = "upwindsecurity/cloudlogs/google//modules/gcp-audit-logs"

  gcp_organization_id        = "123456789"
  infrastructure_project_id  = "my-gcp-project"
  upwind_management_sa_email = "<provided by Upwind>"
  # integration_type = "ORGANIZATION"  # default
}
```

---

### FOLDER

A single folder-level sink routes logs from every project within the specified `folder_id` to Pub/Sub.

**When to use:** The customer wants to limit coverage to a specific organizational unit without granting org-level access.

**Project filtering (optional):**
- `included_project_ids` — only capture logs from these project IDs within the folder
- `excluded_project_ids` — capture all projects in the folder except these
- Neither — capture all projects in the folder

```hcl
module "gcp_audit_logs" {
  source = "upwindsecurity/cloudlogs/google//modules/gcp-audit-logs"

  gcp_organization_id        = "123456789"
  infrastructure_project_id  = "my-gcp-project"
  upwind_management_sa_email = "<provided by Upwind>"
  integration_type           = "FOLDER"
  folder_id                  = "111111111111"
}
```

---

### PROJECT

One sink per entry in `monitored_project_ids`. Captures only the exact projects listed.

**When to use:** The customer wants explicit, project-by-project control with no org or folder access granted.

```hcl
module "gcp_audit_logs" {
  source = "upwindsecurity/cloudlogs/google//modules/gcp-audit-logs"

  gcp_organization_id        = "123456789"
  infrastructure_project_id  = "my-gcp-project"
  upwind_management_sa_email = "<provided by Upwind>"
  integration_type           = "PROJECT"
  monitored_project_ids      = ["project-a", "project-b"]
}
```

> `included_project_ids` / `excluded_project_ids` do not apply to PROJECT type — sinks are already scoped per project.

---

## Resources created

All resources are provisioned on `infrastructure_project_id`.

| Resource | Name pattern | Notes |
|----------|-------------|-------|
| `google_project_service` | — | Enables `pubsub`, `secretmanager`, `iam`, `iamcredentials`, `cloudresourcemanager` |
| `google_service_account` | `audit-logs-runner-{suffix}` | Upwind impersonates this SA via WIF to pull from Pub/Sub |
| `google_iam_workload_identity_pool` | `upwind-{suffix}-pool-{hex}` | Trusts Upwind's AWS account |
| `google_iam_workload_identity_pool_provider` | `upwind-{suffix}-aws-provider` | AWS provider for the WIF pool |
| `google_pubsub_topic` | `upwind-gcp-audit-logs-topic` | Receives logs from Cloud Logging sinks |
| `google_pubsub_subscription` | `upwind-gcp-audit-logs-subscription` | Never expires; 6h retention |
| `google_secret_manager_secret` | `upwind-audit-logs-wif-secret` | Stores WIF credentials JSON (write-only, never in Terraform state) |
| `google_logging_organization_sink` | `upwind-gcp-audit-logs-sink` | ORGANIZATION type only |
| `google_logging_folder_sink` | `upwind-gcp-audit-logs-sink` | FOLDER type — one sink for `folder_id` |
| `google_logging_project_sink` | `upwind-gcp-audit-logs-sink` | PROJECT type — one per `monitored_project_ids` entry |

The Pub/Sub topic, subscription, and Secret Manager secret are labeled `upwind-component=gcp-audit-logs`. Service accounts, IAM roles, IAM bindings, log sinks, and WIF pool/provider do not support labels in GCP.

---

## Permissions granted

| Principal | Role / Permission | Scope | Purpose |
|-----------|-----------------|-------|---------|
| Runner SA | `roles/pubsub.viewer` | Specific Pub/Sub topic only | Verify Pub/Sub topic exists during test-connectivity |
| Runner SA | `roles/logging.viewer` | Org (ORGANIZATION), folder (FOLDER), or each monitored project (PROJECT) | Verify log sink exists during test-connectivity. Grants broader read-only logging access — deliberate tradeoff to avoid requiring `roles/iam.organizationRoleAdmin` for a custom role. |
| Runner SA | `roles/pubsub.subscriber` | Specific subscription only | Pull audit log messages at runtime |
| Runner SA | `roles/monitoring.viewer` | Infrastructure project | Read Pub/Sub backlog metrics (`num_undelivered_messages`, `oldest_unacked_message_age`) so Upwind can monitor ingestion lag |
| Cloud Logging sink writer | `roles/pubsub.publisher` | Specific topic only | Deliver log entries from the sink to Pub/Sub |
| Upwind management SA | `roles/secretmanager.secretAccessor` | Specific secret only | Read WIF credentials JSON once during create-integration |
| Upwind AWS account (WIF) | `roles/iam.workloadIdentityUser` | Runner SA only | Exchange AWS credentials for a short-lived GCP identity token via WIF |

---

## Required permissions to run terraform apply

Only the column matching the chosen `integration_type` applies.

| | Infrastructure project | Org level | Folder level | Per monitored project |
|---|---|---|---|---|
| **ORGANIZATION** | `roles/owner` | `roles/logging.configWriter` + `roles/resourcemanager.organizationAdmin` | — | — |
| **FOLDER** | `roles/owner` | — | `roles/logging.configWriter` + `roles/resourcemanager.folderIamAdmin` | — |
| **PROJECT** | `roles/owner` | — | — | `roles/logging.configWriter` + `roles/resourcemanager.projectIamAdmin` |

- `roles/owner` on the infrastructure project covers Pub/Sub, Secret Manager, IAM, WIF pool, and API enablement.
- The IAM admin role at org/folder/project scope is required specifically to bind `roles/logging.viewer` to the runner SA.
- Simplest option: `roles/owner` at the GCP org level covers all columns.

---

## Authentication flow

No static credentials. Upwind uses keyless Workload Identity Federation:

```
Upwind backend (AWS)
  → exchanges AWS credentials at the WIF pool → federated GCP token
    → calls generateAccessToken on the runner SA → short-lived SA token
      → StreamingPull on the Pub/Sub subscription
```

The WIF credentials JSON (describing how to do this exchange) is stored in Secret Manager and read once by Upwind's management SA during create-integration. After that, Upwind's backend reads it from its own database — Secret Manager is not accessed at runtime.

---

## VPC Service Controls

If your organization uses VPC Service Controls (VPC-SC), two flows must be explicitly allowed — these can be silently blocked even when IAM permissions are correct.

### What needs to be configured

| | What | Detail |
|---|---|---|
| **Access Level** | Sink writer identity | Add `upwind_log_sink_writer_identities` to the Access Level on the destination perimeter. Required for ORGANIZATION and FOLDER sink types — project-level sinks are not affected. |
| **Ingress rule** | Upwind runner SA → Pub/Sub | Allow `upwind_runner_sa_email` to call `pubsub.googleapis.com`: `Pull`, `StreamingPull`, `Acknowledge`, `ModifyAckDeadline` on the infrastructure project. |
| **Restricted service** | Pub/Sub in perimeter | `pubsub.googleapis.com` must be a restricted service in the perimeter containing the infrastructure project. |

### Outputs to use

| Output | Used for |
|--------|----------|
| `upwind_log_sink_writer_identities` | Identity to add to the Access Level |
| `upwind_runner_sa_email` | Identity for the Pub/Sub ingress rule |
| `upwind_pubsub_topic_id` | Resource scoping for the ingress rule |

### Required permission

The identity applying the perimeter changes needs `accesscontextmanager.policies.update` at the organization level — typically the security or platform team, not the onboarding user.

---

## Log sources

| Variable | Default | Charges | Notes |
|----------|---------|---------|-------|
| `enable_admin_activity_logs` | `true` | No | GCP cannot disable this type — variable controls sink routing only |
| `enable_system_event_logs` | `false` | No | GCP cannot disable this type — variable controls sink routing only |
| `enable_data_access_logs` | `false` | Yes | High volume; must also be enabled in GCP org Audit Logs settings. Also captures Google Workspace login events (login.googleapis.com) — requires data sharing enabled in Google Admin console. |
| `enable_policy_denied_logs` | `false` | Yes | Access denied by security policy (e.g. VPC Service Controls) |

The sink filter is built dynamically. When multiple types are enabled they are joined with `OR` and wrapped in parentheses before any project filter is appended — required because `AND` has higher precedence than `OR` in GCP logging query language.

---

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.23.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.23.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_folder_iam_member.log_sink_reader_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder_iam_member) | resource |
| [google_iam_workload_identity_pool.upwind_wif_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.upwind_aws_provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_logging_folder_sink.audit_logs_sink](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_folder_sink) | resource |
| [google_logging_organization_sink.audit_logs_sink](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_organization_sink) | resource |
| [google_logging_project_sink.audit_logs_sink](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink) | resource |
| [google_organization_iam_member.log_sink_reader_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/organization_iam_member) | resource |
| [google_project_iam_member.log_sink_reader_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.runner_sa_monitoring_viewer_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required_apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_pubsub_subscription.audit_logs_subscription](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_subscription_iam_member.runner_sa_subscription_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription_iam_member) | resource |
| [google_pubsub_topic.audit_logs_topic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_binding.log_sink_publisher_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_binding) | resource |
| [google_pubsub_topic_iam_member.runner_sa_topic_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_secret_manager_secret.upwind_wif_secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_member.upwind_sa_secret_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_version.wif_credentials](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.upwind_audit_logs_runner_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.audit_logs_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [random_id.wif_pool_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [google_project.infrastructure_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_admin_activity_logs"></a> [enable\_admin\_activity\_logs](#input\_enable\_admin\_activity\_logs) | Capture Admin Activity audit logs (records admin operations such as creating/modifying resources). Cannot be disabled in GCP — this variable controls whether the sink routes them. | `bool` | `true` | no |
| <a name="input_enable_data_access_logs"></a> [enable\_data\_access\_logs](#input\_enable\_data\_access\_logs) | Capture Data Access audit logs (records API calls that read/write user data) and Google Workspace login events (login.googleapis.com). Disabled by default — generates significant volume and incurs GCP charges. Must also be enabled in GCP org Audit Logs settings. Google Workspace login events additionally require data sharing enabled in the Google Admin console. | `bool` | `false` | no |
| <a name="input_enable_policy_denied_logs"></a> [enable\_policy\_denied\_logs](#input\_enable\_policy\_denied\_logs) | Capture Policy Denied audit logs (records when a principal is denied access due to a security policy violation, e.g. VPC Service Controls). Incurs GCP charges. | `bool` | `false` | no |
| <a name="input_enable_system_event_logs"></a> [enable\_system\_event\_logs](#input\_enable\_system\_event\_logs) | Capture System Event audit logs (records GCP system actions, not user-initiated). Cannot be disabled in GCP — this variable controls whether the sink routes them. | `bool` | `false` | no |
| <a name="input_excluded_project_ids"></a> [excluded\_project\_ids](#input\_excluded\_project\_ids) | GCP project IDs to exclude from the sink. All other projects are captured. Applies to ORGANIZATION and FOLDER integration types. Mutually exclusive with included\_project\_ids. | `list(string)` | `[]` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | The GCP folder ID to create the log sink for. Required when integration\_type is FOLDER. Use included\_project\_ids or excluded\_project\_ids to filter projects within the folder. | `string` | `""` | no |
| <a name="input_folder_log_sources"></a> [folder\_log\_sources](#input\_folder\_log\_sources) | Folder IDs whose folder-level audit log entries should be captured in the org-level sink (e.g. IAM changes on the folder itself). ORGANIZATION type only. Requires included\_project\_ids to be set. | `list(string)` | `[]` | no |
| <a name="input_gcp_organization_id"></a> [gcp\_organization\_id](#input\_gcp\_organization\_id) | The GCP organization ID. Required for all integration types — used to generate unique resource name suffixes and, for ORGANIZATION type, to create the org-level log sink and IAM role. | `string` | n/a | yes |
| <a name="input_included_project_ids"></a> [included\_project\_ids](#input\_included\_project\_ids) | If set, only audit logs from these GCP project IDs are captured. Applies to ORGANIZATION and FOLDER integration types. Mutually exclusive with excluded\_project\_ids. | `list(string)` | `[]` | no |
| <a name="input_infrastructure_project_id"></a> [infrastructure\_project\_id](#input\_infrastructure\_project\_id) | The GCP project ID where all integration resources (Pub/Sub, Service Account, WIF pool, Secret Manager secret) are provisioned. | `string` | n/a | yes |
| <a name="input_integration_type"></a> [integration\_type](#input\_integration\_type) | Integration scope. ORGANIZATION creates an org-level sink, FOLDER creates a folder-level sink for folder\_id, PROJECT creates one sink per entry in monitored\_project\_ids. Use included\_project\_ids or excluded\_project\_ids to filter projects (ORGANIZATION and FOLDER only). | `string` | `"ORGANIZATION"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Additional labels to apply to the Pub/Sub topic, subscription, and Secret Manager secret. Keys and values must be lowercase. The label upwind-component=gcp-audit-logs is always applied and cannot be overridden. | `map(string)` | `{}` | no |
| <a name="input_log_sink_description"></a> [log\_sink\_description](#input\_log\_sink\_description) | An optional description for your log sink. | `string` | `"Upwind audit logs sink."` | no |
| <a name="input_log_sink_exclusions"></a> [log\_sink\_exclusions](#input\_log\_sink\_exclusions) | Additional named exclusion filters applied to the log sink, merged with the default GKE and sys-project exclusions. Matching log entries are dropped before reaching Pub/Sub. Do not reuse the reserved names: exclude-gke-k8s, exclude-sys-projects. | <pre>list(object({<br/>    name        = string<br/>    description = optional(string)<br/>    filter      = string<br/>  }))</pre> | `[]` | no |
| <a name="input_log_sink_name"></a> [log\_sink\_name](#input\_log\_sink\_name) | The name of the log sink (e.g., 'org-all-audit-sink'). Must be unique within the organization. | `string` | `"upwind-gcp-audit-logs-sink"` | no |
| <a name="input_message_retention_duration"></a> [message\_retention\_duration](#input\_message\_retention\_duration) | How long Pub/Sub retains messages on the topic and unacknowledged messages on the subscription. If Upwind's service is down longer than this window, older messages are discarded. GCP range: 600s (10 min) to 604800s (7 days). | `string` | `"21600s"` | no |
| <a name="input_monitored_project_ids"></a> [monitored\_project\_ids](#input\_monitored\_project\_ids) | Project IDs to create log sinks for. Required when integration\_type is PROJECT. Each project gets its own sink routing to the same Pub/Sub topic. | `list(string)` | `[]` | no |
| <a name="input_pubsub_subscription_name"></a> [pubsub\_subscription\_name](#input\_pubsub\_subscription\_name) | The name of the Pub/Sub subscription to create. | `string` | `"upwind-gcp-audit-logs-subscription"` | no |
| <a name="input_pubsub_topic_name"></a> [pubsub\_topic\_name](#input\_pubsub\_topic\_name) | The name of the Pub/Sub topic to create. | `string` | `"upwind-gcp-audit-logs-topic"` | no |
| <a name="input_resource_suffix"></a> [resource\_suffix](#input\_resource\_suffix) | Suffix appended to all resource names to avoid conflicts when running the module more than once in the same project. Applied to sink, Pub/Sub, Secret Manager, SA, WIF pool, and IAM roles. Max 6 lowercase alphanumeric characters. | `string` | `""` | no |
| <a name="input_secret_replication_locations"></a> [secret\_replication\_locations](#input\_secret\_replication\_locations) | Regions for user-managed Secret Manager replication of the WIF credentials secret. Leave empty for automatic (global) replication. Set this only when an org policy (e.g. constraints/gcp.resourceLocations) blocks global secrets — replication is immutable, so this must be set before the secret is first created and cannot be changed on an already-deployed secret without destroying and recreating it. | `list(string)` | `[]` | no |
| <a name="input_upwind_management_sa_email"></a> [upwind\_management\_sa\_email](#input\_upwind\_management\_sa\_email) | Upwind management service account email provided during setup. Granted secretAccessor on the WIF secret. | `string` | n/a | yes |
| <a name="input_upwind_trusted_account_id"></a> [upwind\_trusted\_account\_id](#input\_upwind\_trusted\_account\_id) | Upwind's AWS account ID that the WIF pool will trust. Defaults to Upwind's production account. | `string` | `"340457201789"` | no |
| <a name="input_upwind_wif_secret"></a> [upwind\_wif\_secret](#input\_upwind\_wif\_secret) | Name of the Secret Manager secret where the WIF credentials will be stored. | `string` | `"upwind-audit-logs-wif-secret"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_upwind_log_sink_ids"></a> [upwind\_log\_sink\_ids](#output\_upwind\_log\_sink\_ids) | The full resource IDs of all created log sinks (org, folder, or project depending on integration\_type). |
| <a name="output_upwind_log_sink_writer_identities"></a> [upwind\_log\_sink\_writer\_identities](#output\_upwind\_log\_sink\_writer\_identities) | The Cloud Logging service account emails that write logs to the Pub/Sub topic. One entry per sink. Publisher bindings are managed by this module. |
| <a name="output_upwind_project_number"></a> [upwind\_project\_number](#output\_upwind\_project\_number) | The numeric project number of the infrastructure project. |
| <a name="output_upwind_pubsub_subscription_name"></a> [upwind\_pubsub\_subscription\_name](#output\_upwind\_pubsub\_subscription\_name) | The name of the Pub/Sub subscription for audit logs |
| <a name="output_upwind_pubsub_topic_id"></a> [upwind\_pubsub\_topic\_id](#output\_upwind\_pubsub\_topic\_id) | The fully qualified identifier of the Pub/Sub topic |
| <a name="output_upwind_pubsub_topic_name"></a> [upwind\_pubsub\_topic\_name](#output\_upwind\_pubsub\_topic\_name) | The name of the Pub/Sub topic used for audit logs |
| <a name="output_upwind_runner_sa_email"></a> [upwind\_runner\_sa\_email](#output\_upwind\_runner\_sa\_email) | Email of the runner service account — Upwind impersonates this SA via WIF to pull from Pub/Sub |
| <a name="output_upwind_runner_sa_name"></a> [upwind\_runner\_sa\_name](#output\_upwind\_runner\_sa\_name) | The fully qualified name of the service account |
| <a name="output_upwind_wif_audience"></a> [upwind\_wif\_audience](#output\_upwind\_wif\_audience) | The full audience string for the WIF JSON configuration file. |
| <a name="output_upwind_wif_pool_id"></a> [upwind\_wif\_pool\_id](#output\_upwind\_wif\_pool\_id) | The ID of the GCP Workload Identity Pool (used in the WIF audience URL). |
| <a name="output_upwind_wif_provider_id"></a> [upwind\_wif\_provider\_id](#output\_upwind\_wif\_provider\_id) | The ID of the Workload Identity Pool Provider (AWS) (used in the WIF audience URL). |
| <a name="output_upwind_wif_sa_impersonation_url"></a> [upwind\_wif\_sa\_impersonation\_url](#output\_upwind\_wif\_sa\_impersonation\_url) | The service account impersonation URL for the WIF JSON configuration file. |
| <a name="output_upwind_wif_secret"></a> [upwind\_wif\_secret](#output\_upwind\_wif\_secret) | The name of the Secret Manager secret for Workload Identity Federation configuration |
<!-- END_TF_DOCS -->
