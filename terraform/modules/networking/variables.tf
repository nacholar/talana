variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all networking resources"
  type        = string
  default     = "us-central1"
}

variable "subnet_cidr" {
  description = "CIDR range for the regional subnet"
  type        = string
  default     = "10.10.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block (e.g., 10.10.0.0/24)."
  }
}

variable "pods_cidr" {
  description = "Secondary CIDR range reserved for GKE Pod IPs (VPC-native alias IP mode)"
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr must be a valid CIDR block (e.g., 10.20.0.0/16)."
  }
}

variable "services_cidr" {
  description = "Secondary CIDR range reserved for GKE Service IPs (VPC-native alias IP mode)"
  type        = string
  default     = "10.30.0.0/16"

  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr must be a valid CIDR block (e.g., 10.30.0.0/16)."
  }
}

variable "target_tags" {
  description = "Network tags that restrict which instances the Cloud SQL firewall rule applies to. Empty list applies the rule to all instances in the VPC. Populate with GKE node tags in Story 1.4."
  type        = list(string)
  default     = []
}
