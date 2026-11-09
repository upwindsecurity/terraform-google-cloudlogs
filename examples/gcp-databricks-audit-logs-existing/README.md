# gcp-databricks-audit-logs-existing example

Reads the audit logs a Databricks log delivery already writes to a GCS bucket of yours. No bucket or delivery is
created and Databricks' service account is granted nothing: the module adds a Pub/Sub notification to the bucket for
new files under the delivery prefix (the bucket's other notifications are kept) and the subscription. Upwind reads them
as the management service account of your Upwind GCP onboarding, so apply that first with `enable_dataevents = true`, on
a scope that includes `project_id`.

The bucket must be in `project_id`; the plan fails otherwise.

```bash
terraform init
terraform plan
terraform apply
```

Give the bucket and prefix to the Upwind console. `terraform destroy` removes only what the module added; the bucket,
its files and the Databricks delivery are left as they are.

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.23.0, < 8.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_gcp_databricks_audit_logs"></a> [gcp\_databricks\_audit\_logs](#module\_gcp\_databricks\_audit\_logs) | ../../modules/gcp-databricks-audit-logs | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_delivery_path_prefix"></a> [delivery\_path\_prefix](#input\_delivery\_path\_prefix) | Object name prefix the existing delivery writes under (its delivery path prefix in Databricks). | `string` | n/a | yes |
| <a name="input_existing_bucket_name"></a> [existing\_bucket\_name](#input\_existing\_bucket\_name) | Bucket an existing Databricks audit log delivery writes to. It must be in project\_id. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project that owns the bucket, topic and subscription. It must be in the scope of your Upwind GCP onboarding, applied with enable\_dataevents = true. | `string` | n/a | yes |
| <a name="input_upwind_resource_suffix"></a> [upwind\_resource\_suffix](#input\_upwind\_resource\_suffix) | Resource suffix shown in the Upwind console for this integration. Upwind derives the subscription name from it. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_upwind_delivery_target"></a> [upwind\_delivery\_target](#output\_upwind\_delivery\_target) | What Upwind reads, for reference. |
<!-- END_TF_DOCS -->
