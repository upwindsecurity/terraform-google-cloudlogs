terraform {
  required_version = ">= 1.11.0"

  required_providers {
    # Upper bounds are deliberate: a new provider major must be tested against this
    # module before customers get it. google 8.0.0 broke onboarding by making
    # secret_data_wo_version mandatory alongside secret_data_wo (see secrets.tf).
    google = {
      source  = "hashicorp/google"
      version = ">= 6.23.0, < 8.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0, < 4.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0, < 1.0.0"
    }
  }
}
