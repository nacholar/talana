output "vpc_id" {
  description = "VPC network ID"
  value       = google_compute_network.vpc.id
}

output "subnet_id" {
  description = "Regional subnet ID"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "Regional subnet name (used by GKE cluster placement)"
  value       = google_compute_subnetwork.subnet.name
}

output "vpc_self_link" {
  description = "VPC network self-link URI (used by GKE and Cloud SQL modules)"
  value       = google_compute_network.vpc.self_link
}

output "pods_range_name" {
  description = "Secondary range name for GKE Pod IPs (VPC-native alias IP mode)"
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary range name for GKE Service IPs (VPC-native alias IP mode)"
  value       = "services"
}
