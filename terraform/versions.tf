terraform {
  required_version = ">= 1.3, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend bucket cannot use Terraform variables. Provide via:
  #   terraform init -backend-config="bucket=YOUR_STATE_BUCKET_NAME"
  # or set bucket = "YOUR_STATE_BUCKET_NAME" directly before first init.
  backend "gcs" {
    bucket = "REPLACE_WITH_STATE_BUCKET_NAME"
    prefix = "terraform/state"
  }
}
