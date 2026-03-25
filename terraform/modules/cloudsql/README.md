# Cloud SQL Module

Provisions a Cloud SQL PostgreSQL instance with private IP only (no public IP), using VPC peering for network isolation. Generates a random database password and populates Secret Manager secret versions.

## Architecture

Cloud SQL private IP requires a two-step VPC peering setup:

1. `google_compute_global_address` — reserves a /16 IP block in the VPC for peering
2. `google_service_networking_connection` — peers the VPC with Google's managed services VPC
3. `google_sql_database_instance` — uses the private IP from the peered range (`depends_on` step 2)

Secret Manager secret **resources** (`google_secret_manager_secret`) are created in the IAM module (Story 1.3). This module creates the secret **versions** to populate their values.

## Usage

```hcl
module "cloudsql" {
  source     = "./modules/cloudsql"
  project_id = var.project_id
  region     = var.region
  network    = module.networking.vpc_self_link
}
```

## Prerequisites

The following GCP APIs must be enabled before `terraform apply`:

```bash
gcloud services enable servicenetworking.googleapis.com sqladmin.googleapis.com
```

After adding the `random` provider to `versions.tf`, run `terraform init -upgrade` before `terraform apply`.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_id` | GCP project ID | `string` | — | yes |
| `region` | GCP region for the Cloud SQL instance | `string` | `"us-central1"` | no |
| `network` | VPC network self-link URI for private services access VPC peering | `string` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| `db_private_ip` | Cloud SQL instance private IP address (stored in Secret Manager as `talana-db-host`) |
| `instance_connection_name` | Cloud SQL instance connection name (`project:region:instance`) for Cloud SQL Proxy |
| `db_password` | Generated database password — stored in Secret Manager as `talana-db-password` (sensitive) |

## Resources Created

| Resource | Name |
|----------|------|
| `random_password` | db_password (32 chars) |
| `google_compute_global_address` | `talana-private-ip-range` |
| `google_service_networking_connection` | private_vpc_connection |
| `google_sql_database_instance` | `talana-cloudsql-pg` (POSTGRES_15, db-f1-micro, private IP only) |
| `google_sql_database` | `talana-db` |
| `google_sql_user` | `talana` |
| `google_secret_manager_secret_version` | db_host, db_password, db_name, db_user |
