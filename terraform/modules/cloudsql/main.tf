# Cloud SQL PostgreSQL — private IP only, no public IP (FR30)
# Secret Manager secrets (resources) were created in Story 1.3 IAM module.
# This module creates secret VERSIONS to populate their values.

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Reserve a private IP range for VPC peering with Google services
resource "google_compute_global_address" "private_ip_range" {
  name          = "talana-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network
  project       = var.project_id

  lifecycle {
    create_before_destroy = true
  }
}

# Establish private services access between talana-vpc and Google's service VPC
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  lifecycle {
    create_before_destroy = true
  }
}

# Cloud SQL PostgreSQL instance — private IP, no public IP
resource "google_sql_database_instance" "postgres" {
  name             = "talana-cloudsql-pg"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  deletion_protection = false

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network
    }
  }

  # CRITICAL: must wait for VPC peering before provisioning — Terraform cannot infer this
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "app_db" {
  name     = "talana-db"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

resource "google_sql_user" "app_user" {
  name     = "talana"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
  project  = var.project_id
}

# Populate Secret Manager secret versions (secrets created in Story 1.3)
# DO NOT create google_secret_manager_secret resources here — they already exist in the IAM module

resource "google_secret_manager_secret_version" "db_host" {
  secret      = "projects/${var.project_id}/secrets/talana-db-host"
  secret_data = google_sql_database_instance.postgres.private_ip_address

  lifecycle {
    precondition {
      condition     = length(google_sql_database_instance.postgres.private_ip_address) > 0
      error_message = "Cloud SQL instance private IP is empty — VPC peering may not have completed before provisioning."
    }
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = "projects/${var.project_id}/secrets/talana-db-password"
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret_version" "db_name" {
  secret      = "projects/${var.project_id}/secrets/talana-db-name"
  secret_data = google_sql_database.app_db.name
}

resource "google_secret_manager_secret_version" "db_user" {
  secret      = "projects/${var.project_id}/secrets/talana-db-user"
  secret_data = google_sql_user.app_user.name
}
