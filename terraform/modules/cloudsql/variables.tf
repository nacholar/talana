variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud SQL instance"
  type        = string
  default     = "us-central1"
}

variable "network" {
  description = "VPC network self-link URI for private services access VPC peering (from networking module)"
  type        = string

  validation {
    condition     = can(regex("^https://www\\.googleapis\\.com/compute/v1/projects/", var.network))
    error_message = "network must be a full VPC self-link (https://www.googleapis.com/compute/v1/projects/...)."
  }
}
