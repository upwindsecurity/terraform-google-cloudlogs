#region Locals
locals {
  # Trust scope: any principal from the Upwind AWS account can use this WIF pool
  # to impersonate the runner SA. This is intentionally account-level (not role-level)
  # to accommodate multiple Upwind services.
  wif_member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.upwind_wif_pool.name}/attribute.aws_account/${var.upwind_trusted_account_id}"
}
#endregion

# Stable unique suffix for the WIF pool ID — GCP soft-deletes pools for 30 days, so a new ID avoids conflicts on destroy+re-apply.
# To force a new pool ID: terraform apply -replace=random_id.wif_pool_suffix
resource "random_id" "wif_pool_suffix" {
  byte_length = 4

  keepers = {
    org_id          = var.gcp_organization_id
    resource_suffix = var.resource_suffix
  }
}

resource "google_iam_workload_identity_pool" "upwind_wif_pool" {
  project                   = var.infrastructure_project_id
  workload_identity_pool_id = "upwind-${local.org_id_truncated}-pool-${random_id.wif_pool_suffix.hex}"
  display_name              = "Upwind Identity Pool"
  description               = "Identity pool for external Upwind workloads"
  disabled                  = false

  depends_on = [google_project_service.required_apis]

  lifecycle {
    create_before_destroy = true
  }
}

#region AWS WIF Provider
resource "google_iam_workload_identity_pool_provider" "upwind_aws_provider" {
  project                            = var.infrastructure_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.upwind_wif_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "upwind-${local.org_id_truncated}-aws-provider"
  display_name                       = "Upwind AWS Provider"
  description                        = "Identity pool provider for Upwind AWS workloads"

  attribute_mapping = {
    "google.subject"        = "assertion.arn"
    "attribute.aws_account" = "assertion.account"
  }

  attribute_condition = "assertion.account == '${var.upwind_trusted_account_id}'"

  aws {
    account_id = var.upwind_trusted_account_id
  }
}
#endregion

#region Runner SA — workloadIdentityUser binding
resource "google_service_account_iam_member" "audit_logs_workload_identity" {
  service_account_id = google_service_account.upwind_audit_logs_runner_sa.id
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_member
}
#endregion

