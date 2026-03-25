output "db_private_ip" {
  description = "Cloud SQL instance private IP address (stored in Secret Manager as talana-db-host)"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name (project:region:instance) for Cloud SQL Proxy in Story 2"
  value       = google_sql_database_instance.postgres.connection_name
}

output "db_password" {
  description = "Generated database password — stored in Secret Manager as talana-db-password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}
