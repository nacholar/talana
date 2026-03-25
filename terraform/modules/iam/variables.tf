variable "project_id" {
  description = "GCP project ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (lowercase letters, digits, hyphens; 6-30 chars; start with letter)."
  }
}

variable "github_repo" {
  description = "GitHub repository in org/repo format for WIF attribute condition (e.g. my-org/talana-sre-challenge)"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be in org/repo format using only alphanumerics, dots, hyphens, and underscores."
  }
}
