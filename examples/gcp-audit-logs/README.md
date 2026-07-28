# GCP Audit Logs Example

This example demonstrates organization-wide usage of the `gcp-audit-logs` module —
a single org-level Log Router sink streaming Cloud Audit Logs to Upwind via
Pub/Sub and Workload Identity Federation.

See the [module README](../../modules/gcp-audit-logs/README.md) for the
FOLDER and PROJECT integration types, all inputs/outputs, required permissions,
and VPC Service Controls configuration.

## Usage

To run this example you need to execute:

```bash
terraform init
terraform plan
terraform apply
```

Run `terraform destroy` when you don't need these resources.

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.23.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_gcp_audit_logs"></a> [gcp\_audit\_logs](#module\_gcp\_audit\_logs) | ../../modules/gcp-audit-logs | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_upwind_log_sink_writer_identities"></a> [upwind\_log\_sink\_writer\_identities](#output\_upwind\_log\_sink\_writer\_identities) | Cloud Logging SAs that publish to the topic — one per sink |
| <a name="output_upwind_pubsub_topic_id"></a> [upwind\_pubsub\_topic\_id](#output\_upwind\_pubsub\_topic\_id) | Fully-qualified Pub/Sub topic ID |
| <a name="output_upwind_runner_sa_email"></a> [upwind\_runner\_sa\_email](#output\_upwind\_runner\_sa\_email) | Runner SA email |
<!-- END_TF_DOCS -->
