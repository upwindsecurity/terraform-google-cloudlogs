#region Secrets

resource "google_secret_manager_secret" "upwind_wif_secret" {
  secret_id = "${var.upwind_wif_secret}${local.name_suffix}"
  project   = var.infrastructure_project_id
  labels    = local.common_labels

  replication {
    dynamic "auto" {
      for_each = length(var.secret_replication_locations) == 0 ? [1] : []
      content {}
    }
    dynamic "user_managed" {
      for_each = length(var.secret_replication_locations) > 0 ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.secret_replication_locations
          content {
            location = replicas.value
          }
        }
      }
    }
  }

  depends_on = [google_project_service.required_apis]
}

# WIF credentials JSON for the runner SA. Write-only — never stored in Terraform state.
# replace_triggered_by ensures this version is recreated whenever the WIF pool, provider,
# or SA are recreated — keeping the stored credentials in sync automatically.
resource "google_secret_manager_secret_version" "wif_credentials" {
  secret = google_secret_manager_secret.upwind_wif_secret.id

  secret_data_wo = jsonencode({
    universe_domain                   = "googleapis.com"
    type                              = "external_account"
    audience                          = "//iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.upwind_wif_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.upwind_aws_provider.workload_identity_pool_provider_id}"
    subject_token_type                = "urn:ietf:params:aws:token-type:aws4_request"
    token_url                         = "https://sts.googleapis.com/v1/token"
    service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${google_service_account.upwind_audit_logs_runner_sa.email}:generateAccessToken"
    service_account_impersonation = {
      token_lifetime_seconds = 3600
    }
    credential_source = {
      environment_id           = "aws1"
      region_url               = "http://169.254.169.254/latest/meta-data/placement/availability-zone"
      url                      = "http://169.254.169.254/latest/meta-data/iam/security-credentials"
      imdsv2_session_token_url = "http://169.254.169.254/latest/api/token"
      # {region} is an intentional runtime placeholder — the google-auth-library replaces
      # it with the instance's actual AWS region at token-exchange time (not a Terraform interpolation).
      regional_cred_verification_url = "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
    }
  })

  lifecycle {
    replace_triggered_by = [
      google_iam_workload_identity_pool.upwind_wif_pool,
      google_iam_workload_identity_pool_provider.upwind_aws_provider,
      google_service_account.upwind_audit_logs_runner_sa,
    ]
  }
}

#endregion
