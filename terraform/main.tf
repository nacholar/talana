# Root Terraform composition — GCP GKE Autopilot platform.

module "networking" {
  source        = "./modules/networking"
  project_id    = var.project_id
  project_name  = var.project_name
  region        = var.region
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

module "iam" {
  source       = "./modules/iam"
  project_id   = var.project_id
  project_name = var.project_name
  github_repo  = var.github_repo
}

module "gke" {
  source              = "./modules/gke"
  project_id          = var.project_id
  project_name        = var.project_name
  region              = var.region
  network             = module.networking.vpc_self_link
  subnetwork          = module.networking.subnet_id
  pods_range_name     = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name
  app_sa_email        = module.iam.app_sa_email
}

module "cloudsql" {
  source       = "./modules/cloudsql"
  project_id   = var.project_id
  project_name = var.project_name
  region       = var.region
  network      = module.networking.vpc_self_link

  depends_on = [module.iam] # iam module creates Secret Manager secret resources that cloudsql populates with versions
}

module "artifact_registry" {
  source          = "./modules/artifact-registry"
  project_id      = var.project_id
  project_name    = var.project_name
  region          = var.region
  github_sa_email = module.iam.github_sa_email
}

# Static global IP for the GCP HTTP(S) Load Balancer.
# Name matches the Ingress annotation: kubernetes.io/ingress.global-static-ip-name.
resource "google_compute_global_address" "lb_ip" {
  name    = "${var.project_name}-lb-ip"
  project = var.project_id
}
