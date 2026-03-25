variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "talana"
}

variable "domain" {
  description = "Custom domain for the application (used for TLS cert and ALLOWED_HOSTS)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in org/repo format for WIF attribute condition"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range for the regional subnet"
  type        = string
  default     = "10.10.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE Pod IPs (VPC-native alias IP mode)"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE Service IPs (VPC-native alias IP mode)"
  type        = string
  default     = "10.30.0.0/16"
}
