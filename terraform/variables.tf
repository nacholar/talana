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
  description = "Short project name used as prefix for all GCP resource names (e.g. myapp)"
  type        = string
}

variable "domain" {
  # NOTE: This variable is declared for documentation purposes and for potential future
  # Terraform-managed DNS resources. With the GKE-native ManagedCertificate CRD approach,
  # the domain is NOT consumed by any Terraform resource — it is set in
  # k8s/managed-certificate.yaml and k8s/deployment-{blue,green}.yaml instead.
  description = "Custom domain for the application (documentational; not consumed by Terraform — domain is wired in K8s manifests)"
  type        = string
  default     = "myapp.example.com"
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
