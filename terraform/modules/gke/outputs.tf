output "cluster_name" {
  description = "GKE cluster name for use in kubectl and CD pipeline"
  value       = google_container_cluster.gke_cluster.name
}

output "cluster_endpoint" {
  description = "GKE cluster API server endpoint (HTTPS) — used in kubeconfig generation"
  value       = google_container_cluster.gke_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate — used in kubeconfig generation"
  value       = google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}
