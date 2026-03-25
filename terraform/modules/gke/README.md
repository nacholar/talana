# GKE Module

Provisions a private GKE Autopilot cluster with Workload Identity enabled for the Talana SRE challenge.

## Overview

- **Cluster name:** `talana-gke-cluster`
- **Mode:** Autopilot (Google manages nodes automatically)
- **Networking:** Private nodes (`enable_private_nodes = true`), public endpoint (`enable_private_endpoint = false`)
- **Workload Identity:** Enabled — pods authenticate to GCP services without static credentials
- **Release channel:** REGULAR

## Usage

```hcl
module "gke" {
  source              = "./modules/gke"
  project_id          = var.project_id
  region              = var.region
  network             = module.networking.vpc_self_link
  subnetwork          = module.networking.subnet_id
  pods_range_name     = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name
  app_sa_email        = module.iam.app_sa_email
}
```

## Requirements

| Requirement | Notes |
|---|---|
| Networking module | Must be applied first (provides VPC, subnet, secondary ranges) |
| IAM module | Must be applied first (provides `app_sa_email`) |

## Inputs

| Name | Description | Type | Required |
|---|---|---|---|
| `project_id` | GCP project ID | `string` | yes |
| `region` | GCP region for the GKE cluster | `string` | no (default: `us-central1`) |
| `network` | VPC network self-link URI | `string` | yes |
| `subnetwork` | Subnetwork self-link URI | `string` | yes |
| `pods_range_name` | Secondary IP range name for GKE pods | `string` | yes |
| `services_range_name` | Secondary IP range name for GKE services | `string` | yes |
| `app_sa_email` | App service account email for Workload Identity IAM binding | `string` | yes |
| `k8s_namespace` | Kubernetes namespace of the app ServiceAccount | `string` | no (default: `default`) |
| `k8s_sa_name` | Kubernetes ServiceAccount name to bind via Workload Identity | `string` | no (default: `django-ksa`) |
| `deletion_protection` | Enable Terraform deletion protection (set `true` in production) | `bool` | no (default: `false`) |
| `master_authorized_networks` | CIDR blocks allowed to reach the API server; empty = unrestricted | `list(string)` | no (default: `[]`) |

## Outputs

| Name | Description | Sensitive |
|---|---|---|
| `cluster_name` | GKE cluster name for use in kubectl and CD pipeline | no |
| `cluster_endpoint` | GKE cluster API server endpoint (HTTPS) | yes |
| `cluster_ca_certificate` | Base64-encoded cluster CA certificate | yes |

## Workload Identity

This module creates the GCP-side IAM binding that allows the Kubernetes ServiceAccount `django-ksa`
(in the `default` namespace) to impersonate the app GCP service account.

The K8s-side annotation (`iam.gke.io/gcp-service-account`) must be applied separately in Story 2.3.

## Resources Created

| Resource | Name |
|---|---|
| `google_container_cluster` | `talana-gke-cluster` |
| `google_service_account_iam_member` | Workload Identity binding for `django-ksa` |
