# gcp-databricks-audit-logs

Makes a Databricks account on GCP deliver its audit log into a GCS bucket the customer owns and notifies a Pub/Sub topic
on every write. Run it once per Databricks account.

Upwind reads the bucket and the subscription as the management service account (`upwind-mgmt-...`) of the Upwind GCP
onboarding, through the workload identity federation the onboarding already set up. This module creates no identity,
pool or grant for Upwind. Before applying it, apply the Upwind GCP onboarding module with `enable_dataevents = true`,
on a scope (organization, folder or projects) that includes `project_id`.

It runs in one of two modes:

- **New delivery** (default): the module creates the bucket, and Upwind creates the Databricks log delivery into it when
  the integration is saved.
- **Existing delivery** (`existing_bucket_name` set): a Databricks log delivery already writes to a bucket of yours.
  No bucket is created and Databricks is granted nothing. The module adds a Pub/Sub notification to the bucket,
  additively, and Upwind uses the delivery that is there instead of adding its own. The bucket must be in `project_id`;
  set `delivery_path_prefix` to the delivery's prefix.

```
Databricks log delivery ──writes JSON Lines──▶ GCS bucket ──OBJECT_FINALIZE──▶ Pub/Sub topic ─▶ subscription
                                                   ▲                                                ▲
              upwind-mgmt-... service account of the Upwind GCP onboarding (enable_dataevents = true):
              UpwindDataEvents role = storage.objects.get, pubsub.subscriptions.consume
```

| Databricks step ([docs](https://docs.databricks.com/gcp/en/admin/account-settings/audit-log-delivery)) | Here |
|---|---|
| Multi-region, Standard, uniform-access bucket | `google_storage_bucket.audit_logs` |
| Storage Admin for `log-delivery@databricks-prod-master.iam.gserviceaccount.com` | `google_storage_bucket_iam_member.databricks_delivery` |
| Create the log delivery configuration | Done by Upwind through the account API once the integration is saved; the Databricks Terraform provider's `databricks_mws_log_delivery` supports AWS only |

## Usage

```hcl
provider "google" {
  project = "my-gcp-project"
}

module "gcp_databricks_audit_logs" {
  source = "upwindsecurity/cloudlogs/google//modules/gcp-databricks-audit-logs"

  project_id      = "my-gcp-project"
  resource_suffix = "<suffix shown in the Upwind console>"
}
```

For a delivery that already exists, add:

```hcl
  existing_bucket_name = "<the bucket the delivery writes to>"
  delivery_path_prefix = "<the delivery's prefix>"
```

Upwind derives the bucket and subscription names from the project ID and the suffix, so nothing needs to be pasted back.
For a new delivery, Upwind then creates the log delivery configuration in your Databricks account.

## Behaviour worth knowing

- Files are JSON Lines, one audit event per line, at `<prefix>/workspaceId=<id>/date=<yyyy-mm-dd>/auditlogs_<id>.json`.
  Account-level events land under `workspaceId=0`. Databricks rewrites a file in place as events arrive, so the bucket
  has versioning off and Upwind keeps a per-object offset.
- Delivered files expire after `log_retention_days` (default 7). Upwind reads them within minutes of delivery.
- Upwind's access comes from the onboarding's `enable_dataevents`, not from this module. Without it, or with
  `project_id` outside the onboarded scope, the console's connectivity test fails on the subscription or the bucket.
- The APIs the module enables (Pub/Sub, Storage) are left enabled on destroy.
- Existing delivery: the bucket keeps its other notifications and IAM members, and its lifecycle rules are left as they
  are. `terraform destroy` removes only this module's notification; the bucket and the delivery stay. The plan fails
  if the bucket is in another project than `project_id`, since that project's GCS service agent is the one granted
  publish on the topic.

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.23.0, < 8.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0, < 4.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.23.0, < 8.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_pubsub_subscription.audit_logs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_topic.audit_logs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_member.gcs_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_storage_bucket.audit_logs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.databricks_delivery](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_notification.audit_logs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_notification) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_storage_bucket.existing](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_bucket) | data source |
| [google_storage_project_service_account.gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_labels"></a> [additional\_labels](#input\_additional\_labels) | Extra labels applied to every labelled resource. | `map(string)` | `{}` | no |
| <a name="input_bucket_force_destroy"></a> [bucket\_force\_destroy](#input\_bucket\_force\_destroy) | Delete the bucket on destroy even when it still holds audit log files. Use with care. Ignored with existing\_bucket\_name: the module never deletes a bucket it did not create. | `bool` | `false` | no |
| <a name="input_bucket_location"></a> [bucket\_location](#input\_bucket\_location) | Bucket location. Databricks documents a multi-region bucket (US, EU or ASIA). Ignored with existing\_bucket\_name. | `string` | `"US"` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the GCS bucket to create for delivered audit logs. Empty generates <prefix>-<suffix>. Ignored with existing\_bucket\_name. | `string` | `""` | no |
| <a name="input_databricks_log_delivery_service_account"></a> [databricks\_log\_delivery\_service\_account](#input\_databricks\_log\_delivery\_service\_account) | Databricks' service account that writes audit logs on GCP. Granted Storage Admin on the bucket, as Databricks documents. Not used with existing\_bucket\_name: the delivery that is there already writes. | `string` | `"log-delivery@databricks-prod-master.iam.gserviceaccount.com"` | no |
| <a name="input_delivery_path_prefix"></a> [delivery\_path\_prefix](#input\_delivery\_path\_prefix) | Object name prefix Databricks writes under. Files land at <prefix>/workspaceId=<id>/date=<yyyy-mm-dd>/auditlogs\_<id>.json. No leading or trailing slash, no spaces. With existing\_bucket\_name: the prefix of the delivery already writing to it. | `string` | `"audit-logs"` | no |
| <a name="input_enable_apis"></a> [enable\_apis](#input\_enable\_apis) | Enable the Pub/Sub and Storage APIs on the project. They are left enabled on destroy. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment label applied to every labelled resource. | `string` | `"production"` | no |
| <a name="input_existing_bucket_name"></a> [existing\_bucket\_name](#input\_existing\_bucket\_name) | Name of an existing bucket a Databricks audit log delivery already writes to. Set it to read from that delivery instead of creating a bucket: no bucket is created, Databricks' service account is granted nothing, and Upwind uses the delivery that is there instead of adding its own. The module adds a Pub/Sub notification to the bucket (its other notifications are kept) and grants nothing on it. The bucket must be in project\_id. Set delivery\_path\_prefix to the delivery's prefix. | `string` | `""` | no |
| <a name="input_include_common_labels"></a> [include\_common\_labels](#input\_include\_common\_labels) | Apply the managed\_by and environment labels. | `bool` | `true` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days a delivered file is kept before it is deleted. Upwind reads files within minutes of delivery; 0 keeps them forever. Ignored with existing\_bucket\_name: the existing bucket's lifecycle is left alone. | `number` | `7` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project that owns the bucket, topic and subscription. Upwind reads them through the Upwind GCP onboarding, so the project must be in its onboarded scope with enable\_dataevents = true. | `string` | n/a | yes |
| <a name="input_resource_name_prefix"></a> [resource\_name\_prefix](#input\_resource\_name\_prefix) | Prefix for the bucket, topic and subscription names. Lower case, as GCS bucket names require. | `string` | `"upwind-databricks-audit-logs"` | no |
| <a name="input_resource_suffix"></a> [resource\_suffix](#input\_resource\_suffix) | Suffix for every name this module creates. The Upwind console sets it, so Upwind knows the names without reading the outputs. Empty generates a random one. | `string` | `""` | no |
| <a name="input_subscription_ack_deadline_seconds"></a> [subscription\_ack\_deadline\_seconds](#input\_subscription\_ack\_deadline\_seconds) | How long a notification is hidden after Upwind pulls it. Must exceed the time to read and publish one file. | `number` | `300` | no |
| <a name="input_subscription_message_retention_seconds"></a> [subscription\_message\_retention\_seconds](#input\_subscription\_message\_retention\_seconds) | How long an unacked notification stays on the subscription. Covers an Upwind outage without losing pointers to files. | `number` | `345600` | no |
| <a name="input_subscription_name"></a> [subscription\_name](#input\_subscription\_name) | Name of the Pub/Sub subscription Upwind pulls. Empty generates <prefix>-<suffix>. | `string` | `""` | no |
| <a name="input_topic_name"></a> [topic\_name](#input\_topic\_name) | Name of the Pub/Sub topic that receives bucket notifications. Empty generates <prefix>-<suffix>. | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Bucket Databricks delivers audit logs into: the one created, or existing\_bucket\_name. |
| <a name="output_delivery_path_prefix"></a> [delivery\_path\_prefix](#output\_delivery\_path\_prefix) | Object name prefix the files land under. |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Pub/Sub subscription Upwind pulls. |
| <a name="output_topic_id"></a> [topic\_id](#output\_topic\_id) | Pub/Sub topic receiving bucket notifications. |
| <a name="output_upwind_delivery_target"></a> [upwind\_delivery\_target](#output\_upwind\_delivery\_target) | Delivery target descriptor to paste into the Upwind console. |
<!-- END_TF_DOCS -->
