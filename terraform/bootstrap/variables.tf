variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the state bucket"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "GCS bucket name for Terraform remote state (must be globally unique)"
  type        = string
}
