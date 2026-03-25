# Bootstrap workspace: provisions and tracks the GCS Terraform state bucket.
#
# Bootstrap sequence (run once, in order):
#   1. make bootstrap PROJECT_ID=<id>          # creates bucket via gsutil
#   2. make bootstrap-import PROJECT_ID=<id>   # imports bucket into this workspace
#
# After import, this workspace manages the bucket via IaC.
# Do NOT run terraform apply here before completing step 1.

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.3, < 2.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "state_bucket" {
  name                        = "talana-state-bucket"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
