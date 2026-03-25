# GKE Autopilot cluster — private nodes, public endpoint (for admin kubectl access)
# Workload Identity enabled so pods authenticate to GCP without static credentials

resource "google_container_cluster" "gke_cluster" {
  name     = "talana-gke-cluster"
  location = var.region
  project  = var.project_id

  enable_autopilot = true

  # VPC-native networking — required for Autopilot
  network    = var.network
  subnetwork = var.subnetwork

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private nodes: no public IPs on nodes; endpoint is public (admin access via HTTPS)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  # Workload Identity: enables pods to authenticate as GCP SAs (FR21)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Allow terraform destroy — without this, delete is blocked by default in provider ~>6.0
  # Set var.deletion_protection = true in production environments.
  deletion_protection = var.deletion_protection

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block = cidr_blocks.value
        }
      }
    }
  }
}

# Allow Kubernetes ServiceAccount django-ksa (default namespace) to impersonate app SA
# K8s side: django-ksa must have annotation iam.gke.io/gcp-service-account set (Story 2.3)
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.app_sa_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_sa_name}]"
}
