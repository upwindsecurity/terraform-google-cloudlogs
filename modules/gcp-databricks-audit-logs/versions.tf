terraform {
  required_version = ">= 1.11.0"

  required_providers {
    # Upper bounds are deliberate: a new provider major must be tested against this
    # module before customers get it. Same pins as gcp-audit-logs.
    google = {
      source  = "hashicorp/google"
      version = ">= 6.23.0, < 8.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}
