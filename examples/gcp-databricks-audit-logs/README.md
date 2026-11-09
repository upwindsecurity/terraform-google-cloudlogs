# gcp-databricks-audit-logs example

Delivers a Databricks account's audit logs into a new GCS bucket and notifies a Pub/Sub subscription on every file.
Upwind reads them as the management service account of your Upwind GCP onboarding, so apply that first with
`enable_dataevents = true`, on a scope that includes `project_id`. This module creates no identity or grant for Upwind.

```bash
terraform init
terraform plan
terraform apply
```

Upwind derives the bucket and subscription names from the project ID and resource suffix, and creates the log delivery
configuration in your Databricks account. Run `terraform destroy` when you no longer need these resources.

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
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project that owns the bucket, topic and subscription. It must be in the scope of your Upwind GCP onboarding, applied with enable\_dataevents = true. | `string` | n/a | yes |
| <a name="input_upwind_resource_suffix"></a> [upwind\_resource\_suffix](#input\_upwind\_resource\_suffix) | Resource suffix shown in the Upwind console for this integration. Upwind derives the bucket and subscription names from it. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_upwind_delivery_target"></a> [upwind\_delivery\_target](#output\_upwind\_delivery\_target) | What Upwind reads, for reference. |
<!-- END_TF_DOCS -->
