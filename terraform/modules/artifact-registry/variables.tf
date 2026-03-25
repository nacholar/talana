variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Artifact Registry repository"
  type        = string
  default     = "us-central1"
}

variable "github_sa_email" {
  description = "GitHub Actions service account email for Artifact Registry write access (CD pipeline image pushes)"
  type        = string
}
