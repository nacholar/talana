# Service Accounts

resource "google_service_account" "github_sa" {
  account_id   = "${var.project_name}-github-sa"
  display_name = "GitHub Actions Service Account"
  project      = var.project_id
}

resource "google_service_account" "app_sa" {
  account_id   = "${var.project_name}-app-sa"
  display_name = "Application Service Account"
  project      = var.project_id
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
  workload_identity_pool_id = "${var.project_name}-wif-pool"
  display_name              = "WIF Pool"
  description               = "Workload Identity Pool for GitHub Actions OIDC authentication"
  project                   = var.project_id
}

resource "google_iam_workload_identity_pool_provider" "wif_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.wif_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.project_name}-wif-provider"
  display_name                       = "GitHub OIDC Provider"
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
}

# Allow WIF principal to impersonate the GitHub Actions SA

resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.wif_pool.name}/attribute.repository/${var.github_repo}"
}

# Secret Manager Secrets (NFR5, NFR7)

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_name}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "db_host" {
  secret_id = "${var.project_name}-db-host"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "db_name" {
  secret_id = "${var.project_name}-db-name"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "db_user" {
  secret_id = "${var.project_name}-db-user"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "django_secret_key" {
  secret_id = "${var.project_name}-django-secret-key"
  project   = var.project_id

  replication {
    auto {}
  }
}
