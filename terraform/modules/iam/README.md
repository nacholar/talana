# IAM Module

Provisions least-privilege service accounts, Workload Identity Federation (WIF) for GitHub Actions OIDC authentication, and Secret Manager secrets for the Talana application. No long-lived GCP credentials are created anywhere.

## Resources Created

| Resource | GCP Name | Purpose |
|---|---|---|
| `google_service_account.github_sa` | `talana-github-sa` | GitHub Actions identity for CD pipeline |
| `google_service_account.app_sa` | `talana-app-sa` | Application pod identity (GKE Workload Identity) |
| `google_project_iam_member.app_sa_cloudsql` | — | Grants `roles/cloudsql.client` to app SA at project level |
| `google_secret_manager_secret_iam_member.app_sa_*` | — | Grants `roles/secretmanager.secretAccessor` to app SA per-secret (5 bindings) |
| `google_iam_workload_identity_pool.wif_pool` | `talana-wif-pool` | WIF pool for GitHub OIDC tokens |
| `google_iam_workload_identity_pool_provider.wif_provider` | `talana-wif-provider` | OIDC provider scoped to `var.github_repo` |
| `google_service_account_iam_member.wif_binding` | — | Binds WIF principal to `talana-github-sa` |
| `google_secret_manager_secret.db_password` | `talana-db-password` | DB password (version added in Story 1.5) |
| `google_secret_manager_secret.db_host` | `talana-db-host` | DB host (version added in Story 1.5) |
| `google_secret_manager_secret.db_name` | `talana-db-name` | DB name (version added in Story 1.5) |
| `google_secret_manager_secret.db_user` | `talana-db-user` | DB user (version added in Story 1.5) |
| `google_secret_manager_secret.django_secret_key` | `talana-django-secret-key` | Django secret key (added manually pre-deploy) |

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_id` | `string` | — | yes | GCP project ID |
| `github_repo` | `string` | — | yes | GitHub repository in `org/repo` format for WIF attribute condition |

## Outputs

| Name | Description |
|---|---|
| `app_sa_email` | App service account email — used by GKE Workload Identity binding in Story 1.4 |
| `github_sa_email` | GitHub Actions service account email — used as `service_account` in CD pipeline OIDC auth step |
| `wif_provider_name` | Full WIF provider resource name (`projects/.../providers/...`) — used as `workload_identity_provider` in CD pipeline |

## WIF Authentication Flow

```
GitHub Actions job
  → requests OIDC token from GitHub (issuer: token.actions.githubusercontent.com)
  → calls google-github-actions/auth with:
      workload_identity_provider: <wif_provider_name output>
      service_account: <github_sa_email output>
  → GCP validates: token issuer + attribute.repository == var.github_repo
  → GCP grants short-lived access token impersonating talana-github-sa
  → CD pipeline authenticates with no stored keys (FR20, NFR5)
```

## Notes

- **Secret Manager bindings** are scoped per-secret (not project-wide) to enforce least privilege. `app_sa` can only access the five secrets defined in this module.
- **Cloud SQL binding** remains at project level pending Story 1.5 (Cloud SQL instance not yet provisioned). Story 1.5 should migrate this to an instance-level binding.
- **Lifecycle protection** (`prevent_destroy = true`) is set on all stateful resources (SAs, WIF pool/provider, secrets) to prevent accidental destruction. GCP soft-deletes WIF pools/providers and secrets with a 30-day retention window; service account emails are unrecoverable for 37 days.
- `github_sa` is granted no IAM roles in this module. CD pipeline roles (e.g. `roles/artifactregistry.writer`) must be added in Story 4.x.

## Usage

```hcl
module "iam" {
  source      = "./modules/iam"
  project_id  = var.project_id
  github_repo = var.github_repo
}
```
