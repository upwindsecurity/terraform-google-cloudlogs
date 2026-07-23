# Terraform Modules for Google Cloud Logs

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/)
[![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge)](https://opensource.org/licenses/Apache-2.0)

## Overview

This repository contains the following Terraform modules for Google Cloud Platform logs.

These modules automate the creation of the GCP Log Router sinks, Pub/Sub infrastructure,
and Workload Identity Federation needed to stream GCP logs to Upwind for centralized
observability and threat detection.

## Modules

- [modules/gcp-audit-logs/](https://github.com/upwindsecurity/terraform-google-cloudlogs/tree/main/modules/gcp-audit-logs/) -
  Streams GCP Cloud Audit Logs to Upwind via a Log Router sink, Pub/Sub, and Workload
  Identity Federation. Supports organization, folder, and project scope.

## Examples

Complete usage examples are available in the
[examples](https://github.com/upwindsecurity/terraform-google-cloudlogs/tree/main/examples/) directory:

- [gcp-audit-logs](https://github.com/upwindsecurity/terraform-google-cloudlogs/tree/main/examples/gcp-audit-logs/) -
  Organization-wide audit log streaming

## Usage

```hcl
module "gcp_audit_logs" {
  source = "upwindsecurity/cloudlogs/google//modules/gcp-audit-logs"

  gcp_organization_id        = "YOUR_ORG_ID"
  infrastructure_project_id  = "YOUR_PROJECT_ID"
  upwind_management_sa_email = "upwind-mgmt-xxxxx@your-project.iam.gserviceaccount.com"
}
```

See [examples/gcp-audit-logs](https://github.com/upwindsecurity/terraform-google-cloudlogs/tree/main/examples/gcp-audit-logs/)
for a full example, and the
[module README](https://github.com/upwindsecurity/terraform-google-cloudlogs/tree/main/modules/gcp-audit-logs/)
for all variables.

## Contributing

We welcome contributions! Please see our
[CONTRIBUTING.md](https://github.com/upwindsecurity/terraform-google-cloudlogs/blob/main/CONTRIBUTING.md) guide for
details on:

- Development setup and workflows
- Testing procedures
- Code standards and best practices
- How to add new submodules

For bug reports and feature requests, please use
[GitHub Issues](https://github.com/upwindsecurity/terraform-google-cloudlogs/issues).

## Versioning

We use [Semantic Versioning](http://semver.org/) for releases. For the versions
available, see the [tags on this repository](https://github.com/upwindsecurity/terraform-google-cloudlogs/tags).

Releases are created automatically by semantic-release on every merge to `main`. The
commit message type determines the version bump:

- `fix:` → patch
- `feat:` → minor
- breaking change → major

## License

This project is licensed under the Apache License 2.0. See the
[LICENSE](https://github.com/upwindsecurity/terraform-google-cloudlogs/blob/main/LICENSE) file for details.

## Support

- [Documentation](https://docs.upwind.io)
- [Issues](https://github.com/upwindsecurity/terraform-google-cloudlogs/issues)
- [Contributing Guide](https://github.com/upwindsecurity/terraform-google-cloudlogs/blob/main/CONTRIBUTING.md)
