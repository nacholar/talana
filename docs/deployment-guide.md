# Deployment Guide

This guide takes you from a blank GCP project to a fully running environment — infrastructure,
Kubernetes workloads, TLS, and automated Blue/Green CD — using only the repo and CLI commands.

> **Note:** One step (DNS A record creation) requires your domain registrar's web UI, as there
> is no universal CLI command for registrar-side DNS management. Every other step is a CLI command.

---

## Prerequisites

All tools must be installed and authenticated before starting.

| Tool | Minimum version | Verify |
|------|-----------------|--------|
| `gcloud` CLI | any recent | `gcloud version` |
| `terraform` | >= 1.3 | `terraform version` |
| `kubectl` | any recent | `kubectl version --client` |
| `docker` | any recent | `docker version` |
| `gsutil` | bundled with gcloud | `gsutil version` |

**Authenticate gcloud:**

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <PROJECT_ID>
```

**You will also need:**

- A GCP project with billing enabled
- Owner or Editor IAM role on the project (Terraform provisions all IAM bindings)
- A GitHub repository with Actions enabled
- Your GitHub repository in `<owner>/<repo>` format (used for WIF attribute condition)
- A custom domain with DNS management access (for TLS provisioning in section 7)

---

## 1. Clone the Repository

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>
```

---

## 2. Bootstrap Terraform State

Creates the GCS bucket that stores Terraform remote state.
**This is a one-time step — do not re-run on subsequent applies.**

Choose a globally unique bucket name (e.g. `myapp-tf-state-<random>`):

```bash
bash scripts/bootstrap-state.sh <gcp-project-id> <bucket-name>
# Optional: specify a region (default: us-central1)
# bash scripts/bootstrap-state.sh <gcp-project-id> <bucket-name> us-central1
```

Verify:

```bash
gsutil ls gs://<bucket-name>
```

After creating the bucket, import it into `terraform/bootstrap` state so Terraform tracks it.
**This must be done before `terraform init` in section 4:**

```bash
make bootstrap-import PROJECT_ID=<gcp-project-id> BUCKET_NAME=<bucket-name>
```

> **Note:** The bucket is created outside of Terraform and is not destroyed by `terraform destroy`.
> See the Teardown section for removal instructions.

---

## 3. Configure Terraform Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your values
```

> **Important:** `terraform.tfvars` is `.gitignore`d — never commit it.

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP project ID | `my-gcp-project` |
| `region` | GCP region | `us-central1` |
| `project_name` | Name prefix for all GCP resources | `myapp` |
| `github_repo` | GitHub repository in `owner/repo` format | `myorg/my-repo` |
| `domain` | Custom domain for HTTPS | `myapp.example.com` |
| `subnet_cidr` | Primary subnet CIDR | `10.10.0.0/24` |
| `pods_cidr` | GKE Pod secondary range CIDR | `10.20.0.0/16` |
| `services_cidr` | GKE Service secondary range CIDR | `10.30.0.0/16` |

> **Note:** The `domain` variable is **not** wired into K8s manifests by Terraform — the
> bootstrap script handles substitution in section 6.

Also update `terraform/versions.tf`: set `bucket` in the GCS backend to your bucket name,
or pass it via `terraform init -backend-config="bucket=<bucket-name>"`.

---

## 4. Apply Infrastructure

```bash
cd terraform/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform provisions resources in this order (dependency-driven):
Networking → IAM + WIF → GKE Autopilot → Cloud SQL → Artifact Registry → Static LB IP

**Expected duration:** ~15–20 minutes on a fresh project.

Capture the outputs — you will need them in later steps:

```bash
terraform output -raw lb_ip            # → Static IP for DNS A record
terraform output -raw cluster_name     # → GKE cluster name
terraform output -raw registry_url     # → Artifact Registry URL (for Docker pushes)
terraform output -raw wif_provider_name  # → WIF provider resource name (for GitHub secret)
terraform output -raw github_sa_email    # → GitHub Actions SA email (for GitHub secret)
```

---

## 5. Configure kubectl

```bash
CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
REGION=$(cd terraform && terraform output -raw region 2>/dev/null || echo "us-central1")

gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --project <project_id>
```

Verify:

```bash
kubectl get nodes
# Autopilot: zero nodes listed is expected — nodes are provisioned on demand when pods schedule
kubectl get namespaces
```

---

## 6. Apply Kubernetes Manifests

The `k8s-bootstrap.sh` script substitutes all placeholders (`APP_NAME`, `PROJECT_ID`,
`YOUR_DOMAIN`, `GIT_SHA`) from your `terraform.tfvars` and applies all manifests in the correct order:

```bash
make k8s-bootstrap
```

Verify objects were created:

```bash
kubectl get deployment django-blue django-green
kubectl get ingress django-ingress
```

> **Note:** Deployment pods will show `0/1 Ready` at this point — the image tag (`GIT_SHA`)
> is still a placeholder and will be resolved by the CD pipeline on the first push (section 8).

> **Note on GKE Autopilot:** When pods first schedule, Autopilot provisions nodes on demand —
> this can take several minutes. The pod may appear stuck briefly before reaching `Running`.

---

## 7. Configure DNS & TLS

### 7a. Get the load balancer IP

```bash
cd terraform/
terraform output -raw lb_ip
# Example output: 34.120.x.x
```

### 7b. Create the DNS A record

Point your custom domain to the LB IP in your domain registrar's DNS settings.

### 7c. Verify DNS propagation

```bash
dig +short <your-domain>
# Expected: the LB IP address
```

### 7d. Monitor TLS certificate provisioning (~15 minutes after DNS resolves)

```bash
APP_NAME=$(grep 'project_name' terraform/terraform.tfvars | head -1 | sed 's/.*= *"\(.*\)"/\1/')
kubectl describe managedcertificate "${APP_NAME}-ssl-cert"
# Look for:  Status: Active
```

### 7e. Verify HTTPS

```bash
curl -I https://<your-domain>/healthz/
# Expected: HTTP/2 200
```

---

## 8. First Deployment — Push to main

Configure the required GitHub Actions secrets (**Settings → Secrets and variables → Actions**):

| Secret name | Value |
|-------------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `APP_NAME` | Your `project_name` value from `terraform.tfvars` |
| `WIF_PROVIDER` | `terraform output -raw wif_provider_name` |
| `GCP_SA_EMAIL` | `terraform output -raw github_sa_email` |
| `GKE_CLUSTER` | `terraform output -raw cluster_name` |
| `GKE_REGION` | Your GCP region (e.g. `us-central1`) |

> **Important:** Do not push to `main` before section 6 is complete. The CD pipeline's slot
> detection step requires `django-ingress` to exist in the cluster.

Trigger the pipeline:

```bash
git push origin main
```

---

## 9. Verify the Live Application

```bash
# Confirm pods are running
kubectl rollout status deployment/django-blue
kubectl rollout status deployment/django-green

# HTTPS health check via domain (once cert is Active)
curl https://<your-domain>/healthz/

# Confirm which slot is currently serving traffic
kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'
# Output: django-blue-svc or django-green-svc
```

---

## Rollback Procedure

Both slots remain running after each deploy. Rollback requires only an Ingress pointer change:

```bash
# Detect current active slot
kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'

# Switch to the previous slot (replace <SLOT> with blue or green)
make rollback SLOT=<SLOT>
```

The GCP load balancer propagates the change in under 30 seconds.

---

## Teardown

```bash
# Remove K8s resources first — allows GCP LB and NEGs to be cleaned up
kubectl delete -f k8s/

# Wait for the LB to release
until ! kubectl get ingress django-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q .; do
  echo "Waiting for LB to release..."; sleep 15
done

# Destroy all Terraform-managed GCP resources
make destroy
```

> **Note:** `terraform destroy` does NOT remove the GCS state bucket — it was created outside
> of Terraform. Remove it manually when no longer needed:
>
> ```bash
> gsutil rm -r gs://<bucket-name>
> ```
