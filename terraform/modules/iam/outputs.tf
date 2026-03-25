output "app_sa_email" {
  description = "App service account email — used by GKE Workload Identity binding in Story 1.4"
  value       = google_service_account.app_sa.email
}

output "github_sa_email" {
  description = "GitHub Actions service account email — used as service_account in CD pipeline OIDC auth step"
  value       = google_service_account.github_sa.email
}

output "wif_provider_name" {
  description = "Full WIF provider resource name (projects/.../providers/...) — used as workload_identity_provider in CD pipeline"
  value       = google_iam_workload_identity_pool_provider.wif_provider.name
}
