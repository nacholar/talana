# Outputs populated as modules are implemented (Stories 1.2 - 1.6).
# Module-dependent outputs are commented out until modules are implemented
# to keep `terraform validate` usable at the scaffold stage.

output "cluster_name" {
  description = "GKE cluster name for use in kubectl and CD pipeline"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster API server endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "registry_url" {
  description = "Artifact Registry URL for Docker image pushes"
  value       = module.artifact_registry.repository_url
}

output "db_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.cloudsql.db_private_ip
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name for Cloud SQL Proxy"
  value       = module.cloudsql.instance_connection_name
}

output "lb_ip" {
  description = "GCP HTTP(S) Load Balancer static IP for DNS configuration"
  value       = google_compute_global_address.lb_ip.address
}

output "vpc_id" {
  description = "VPC network ID"
  value       = module.networking.vpc_id
}

output "subnet_id" {
  description = "Subnet ID for GKE cluster placement"
  value       = module.networking.subnet_id
}

output "vpc_self_link" {
  description = "VPC self-link for Cloud SQL VPC peering and GKE cluster"
  value       = module.networking.vpc_self_link
}

output "subnet_name" {
  description = "Subnet name for GKE cluster placement"
  value       = module.networking.subnet_name
}

output "pods_range_name" {
  description = "Secondary range name for GKE Pod IPs"
  value       = module.networking.pods_range_name
}

output "services_range_name" {
  description = "Secondary range name for GKE Service IPs"
  value       = module.networking.services_range_name
}

output "app_sa_email" {
  description = "App service account email for GKE Workload Identity binding"
  value       = module.iam.app_sa_email
}

output "github_sa_email" {
  description = "GitHub Actions service account email for CD pipeline OIDC auth"
  value       = module.iam.github_sa_email
}

output "wif_provider_name" {
  description = "WIF provider resource name for GitHub Actions OIDC authentication"
  value       = module.iam.wif_provider_name
}
