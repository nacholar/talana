# Artifact Registry Module

Provisions a Google Artifact Registry Docker repository for CD pipeline image pushes and grants the GitHub Actions service account write access scoped to the repository (least-privilege, not project-wide).

## Architecture

- `google_artifact_registry_repository` — Docker format repository named `talana-artifact-registry` in the configured region
- `google_artifact_registry_repository_iam_member` — grants `roles/artifactregistry.writer` to the GitHub Actions SA, scoped to the repository (not `google_project_iam_member`)

GKE Autopilot nodes in the same GCP project can pull images from Artifact Registry without additional IAM grants (node pool SA has implicit read access to same-project registries).

## Usage

```hcl
module "artifact_registry" {
  source          = "./modules/artifact-registry"
  project_id      = var.project_id
  region          = var.region
  github_sa_email = module.iam.github_sa_email
}
```

## Prerequisites

The Artifact Registry API must be enabled before `terraform apply`:

```bash
gcloud services enable artifactregistry.googleapis.com
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_id` | GCP project ID | `string` | — | yes |
| `region` | GCP region for the Artifact Registry repository | `string` | `"us-central1"` | no |
| `github_sa_email` | GitHub Actions service account email for Artifact Registry write access (CD pipeline image pushes) | `string` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| `repository_url` | Artifact Registry Docker repository base URL for CD pipeline image pushes (append `/image:tag`) |

## Resources Created

| Resource | Name |
|----------|------|
| `google_artifact_registry_repository` | `talana-artifact-registry` (DOCKER format, regional) |
| `google_artifact_registry_repository_iam_member` | `github_sa_writer` (`roles/artifactregistry.writer` for GitHub SA) |

## Notes

- `format = "DOCKER"` must be uppercase
- The Docker push URL format is `{location}-docker.pkg.dev/{project_id}/{repository_id}` — NOT the GCP resource name (`registry.name`)
- CD pipeline (Story 4.1) pushes to `${registry_url}/django:{40-char-sha}` — no `latest` tag
- No `deletion_protection` attribute on Artifact Registry repositories; `terraform destroy` works cleanly
- Cleanup policy retains the 10 most recent image versions per tag; older versions are deleted automatically
