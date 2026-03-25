variable "project_id" {
  description = "GCP project ID"
  type        = string
  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "GCP region for the GKE cluster (regional cluster)"
  type        = string
  default     = "us-central1"
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must be a GCP region (e.g. us-central1), not a zone."
  }
}

variable "network" {
  description = "VPC network self-link URI for the GKE cluster (from networking module)"
  type        = string
  validation {
    condition     = can(regex("^https://www\\.googleapis\\.com/", var.network))
    error_message = "network must be a full self-link URI (https://www.googleapis.com/...)."
  }
}

variable "subnetwork" {
  description = "Subnetwork self-link URI for the GKE cluster (from networking module)"
  type        = string
  validation {
    condition     = can(regex("^projects/", var.subnetwork))
    error_message = "subnetwork must be a resource ID (projects/<project>/regions/<region>/subnetworks/<name>)."
  }
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for GKE pods (from networking module)"
  type        = string
  validation {
    condition     = length(trimspace(var.pods_range_name)) > 0
    error_message = "pods_range_name must not be empty."
  }
}

variable "services_range_name" {
  description = "Name of the secondary IP range for GKE services (from networking module)"
  type        = string
  validation {
    condition     = length(trimspace(var.services_range_name)) > 0
    error_message = "services_range_name must not be empty."
  }
}

variable "app_sa_email" {
  description = "App service account email for Workload Identity IAM binding (from IAM module)"
  type        = string
  validation {
    condition     = can(regex("^.+@.+\\.iam\\.gserviceaccount\\.com$", var.app_sa_email))
    error_message = "app_sa_email must be a valid GCP service account email (e.g. name@project.iam.gserviceaccount.com)."
  }
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where django-ksa ServiceAccount resides (Workload Identity binding)"
  type        = string
  default     = "default"
}

variable "k8s_sa_name" {
  description = "Kubernetes ServiceAccount name to bind to the app GCP service account (Workload Identity)"
  type        = string
  default     = "django-ksa"
}

variable "deletion_protection" {
  description = "Whether to enable Terraform deletion protection on the GKE cluster. Set true in production."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks allowed to reach the cluster API server. Empty list = unrestricted (default, suitable for dev)."
  type        = list(string)
  default     = []
}
