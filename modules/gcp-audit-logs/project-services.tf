#region Project Services

resource "google_project_service" "required_apis" {
  for_each = toset([
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  project            = var.infrastructure_project_id
  service            = each.value
  disable_on_destroy = false
}

#endregion
