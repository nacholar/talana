# Service Accounts

resource "google_service_account" "github_sa" {
  account_id   = "talana-github-sa"
  display_name = "Talana GitHub Actions Service Account"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "app_sa" {
  account_id   = "talana-app-sa"
  display_name = "Talana Application Service Account"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

# GitHub Actions SA IAM bindings

resource "google_project_iam_member" "github_sa_container_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_sa.email}"
}

# App SA IAM bindings — least privilege (FR23, NFR9)

resource "google_project_iam_member" "app_sa_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# Secret Manager bindings scoped per-secret (least privilege — not project-wide)

resource "google_secret_manager_secret_iam_member" "app_sa_db_password" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "app_sa_db_host" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_host.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "app_sa_db_name" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_name.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "app_sa_db_user" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_user.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "app_sa_django_secret_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.django_secret_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}

# Workload Identity Federation (FR20)

resource "google_iam_workload_identity_pool" "wif_pool" {
  workload_identity_pool_id = "talana-wif-pool"
  display_name              = "Talana WIF Pool"
  description               = "Workload Identity Pool for GitHub Actions OIDC authentication"
  project                   = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_iam_workload_identity_pool_provider" "wif_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.wif_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "talana-wif-provider"
  display_name                       = "Talana GitHub OIDC Provider"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "attribute.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Allow WIF principal to impersonate the GitHub Actions SA

resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.wif_pool.name}/attribute.repository/${var.github_repo}"
}

# Secret Manager Secrets (NFR5, NFR7)
# Secrets are created here; values (versions) are set separately:
# - talana-db-host, talana-db-password, talana-db-name, talana-db-user → populated in Story 1.5
# - talana-django-secret-key → populated manually before first deployment

resource "google_secret_manager_secret" "db_password" {
  secret_id = "talana-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret" "db_host" {
  secret_id = "talana-db-host"
  project   = var.project_id

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret" "db_name" {
  secret_id = "talana-db-name"
  project   = var.project_id

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret" "db_user" {
  secret_id = "talana-db-user"
  project   = var.project_id

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret" "django_secret_key" {
  secret_id = "talana-django-secret-key"
  project   = var.project_id

  replication {
    auto {}
  }

  lifecycle {
    prevent_destroy = true
  }
}
