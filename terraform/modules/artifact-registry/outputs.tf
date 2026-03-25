output "repository_url" {
  description = "Artifact Registry Docker repository base URL for CD pipeline image pushes (append /image:tag)"
  value       = "${google_artifact_registry_repository.registry.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.registry.repository_id}"
}
