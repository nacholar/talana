output "state_bucket_name" {
  description = "GCS bucket name for Terraform state"
  value       = google_storage_bucket.state_bucket.name
}
