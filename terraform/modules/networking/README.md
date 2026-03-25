# Networking Module

Provisions the core networking layer for the talana infrastructure: a private VPC, a regional subnet with Google API access and GKE secondary IP ranges, Cloud Router, Cloud NAT for outbound internet access, VPC flow logs, and a firewall rule restricting Cloud SQL access to port 5432 within the VPC.

## Resources Created

| Resource | Name | Description |
|---|---|---|
| `google_compute_network` | `talana-vpc` | Custom VPC with manual subnet creation |
| `google_compute_subnetwork` | `talana-subnet` | Regional private subnet with Private Google Access, GKE secondary ranges, and flow logs |
| `google_compute_router` | `talana-router` | Cloud Router for NAT gateway attachment |
| `google_compute_router_nat` | `talana-cloud-nat` | Cloud NAT for outbound internet access (no public node IPs), scoped to this subnet only |
| `google_compute_firewall` | `talana-allow-cloudsql` | Firewall rule allowing TCP 5432 from subnet CIDR only |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | required | GCP project ID |
| `region` | `string` | `"us-central1"` | GCP region for all networking resources |
| `subnet_cidr` | `string` | `"10.10.0.0/24"` | Primary CIDR range for the regional subnet |
| `pods_cidr` | `string` | `"10.20.0.0/16"` | Secondary CIDR range for GKE Pod IPs (VPC-native alias IP mode) |
| `services_cidr` | `string` | `"10.30.0.0/16"` | Secondary CIDR range for GKE Service IPs (VPC-native alias IP mode) |
| `target_tags` | `list(string)` | `[]` | Network tags to restrict Cloud SQL firewall targets. Empty = applies to all instances. Populate with GKE node tags in Story 1.4. |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC network ID |
| `subnet_id` | Regional subnet ID |
| `subnet_name` | Regional subnet name (used by GKE cluster placement) |
| `vpc_self_link` | VPC network self-link URI (used by GKE and Cloud SQL modules) |
| `pods_range_name` | Secondary range name for GKE Pod IPs (`"pods"`) |
| `services_range_name` | Secondary range name for GKE Service IPs (`"services"`) |

## Usage

```hcl
module "networking" {
  source        = "./modules/networking"
  project_id    = var.project_id
  region        = var.region
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}
```
