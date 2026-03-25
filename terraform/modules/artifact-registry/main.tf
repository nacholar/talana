# Artifact Registry — Docker repository for CD pipeline image pushes (FR5)

resource "google_artifact_registry_repository" "registry" {
  repository_id = "talana-artifact-registry"
  location      = var.region
  format        = "DOCKER"
  description   = "Docker repository for talana application images"
  project       = var.project_id

  cleanup_policies {
    id     = "keep-last-10"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
}

# Grant GitHub Actions SA write access for CD pipeline image pushes (FR5)
resource "google_artifact_registry_repository_iam_member" "github_sa_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.registry.location
  repository = google_artifact_registry_repository.registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.github_sa_email}"
}
