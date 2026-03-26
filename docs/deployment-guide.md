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
- A GCP billing account linked to the project (`gcloud billing accounts list` to find yours)
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

Creates the GCS bucket (`talana-state-bucket`) that stores Terraform remote state.
**This is a one-time step — do not re-run on subsequent applies.**

```bash
bash scripts/bootstrap-state.sh <gcp-project-id>
# Optional: specify a region (default: us-central1)
# bash scripts/bootstrap-state.sh <gcp-project-id> us-central1
```

Verify:

```bash
gsutil ls gs://talana-state-bucket
# Expected: gs://talana-state-bucket/ listed (versioning enabled)
```

After creating the bucket, import it into `terraform/bootstrap` state so Terraform tracks it.
**This must be done before `terraform init` in section 4:**

```bash
make bootstrap-import PROJECT_ID=<gcp-project-id>
# Runs: cd terraform/bootstrap && terraform init && terraform import ... talana-state-bucket
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

Every required variable:

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP project ID | `my-talana-project` |
| `region` | GCP region | `us-central1` |
| `project_name` | Project name prefix for resource naming | `talana` |
| `github_repo` | GitHub repository in `owner/repo` format | `myorg/talana-sre-challenge` |
| `domain` | Custom domain for HTTPS | `talana.example.com` |
| `subnet_cidr` | Primary subnet CIDR | `10.10.0.0/24` |
| `pods_cidr` | GKE Pod secondary range CIDR | `10.20.0.0/16` |
| `services_cidr` | GKE Service secondary range CIDR | `10.30.0.0/16` |

> **Note:** The `domain` variable is **not** wired into K8s manifests by Terraform — you will
> substitute it directly in the manifests in section 6.

---

## 4. Apply Infrastructure

`terraform/versions.tf` configures a GCS remote backend pointing at `talana-state-bucket`.
Running `terraform init` will connect to that bucket — make sure section 2 (bootstrap + import)
is complete before this step.

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

> **Note:** `terraform apply` is run manually here with a plan review. In the CD pipeline,
> `-auto-approve` is used. Never use `-auto-approve` locally.

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

Several manifests contain placeholders that must be substituted before applying.
Run these substitutions from the repo root:

```bash
PROJECT_ID=$(cd terraform && terraform output -raw project_id 2>/dev/null || echo "<your-project-id>")
DOMAIN=$(cd terraform && terraform output -raw domain 2>/dev/null || echo "<your-domain>")

# Substitute PROJECT_ID into the ServiceAccount (Workload Identity annotation)
sed -i "s/PROJECT_ID/${PROJECT_ID}/g" k8s/serviceaccount.yaml

# Substitute domain into the ManagedCertificate and Deployment manifests
sed -i "s/talana\.nacholar\.com/${DOMAIN}/g" k8s/managed-certificate.yaml
sed -i "s/talana\.nacholar\.com/${DOMAIN}/g" k8s/deployment-blue.yaml k8s/deployment-green.yaml

# Substitute PROJECT_ID into the Deployment manifests
# GIT_SHA will be replaced by the CD pipeline on the first push (section 8)
sed -i "s/PROJECT_ID/${PROJECT_ID}/g" k8s/deployment-blue.yaml k8s/deployment-green.yaml
```

Apply manifests in this exact order (dependencies flow top-to-bottom):

```bash
kubectl apply -f k8s/serviceaccount.yaml        # GKE Workload Identity KSA — must exist before pods
kubectl apply -f k8s/managed-certificate.yaml   # ManagedCertificate CRD — must exist before Ingress
kubectl apply -f k8s/frontend-config.yaml        # FrontendConfig CRD — must exist before Ingress
kubectl apply -f k8s/deployment-blue.yaml
kubectl apply -f k8s/deployment-green.yaml
kubectl apply -f k8s/service-blue.yaml
kubectl apply -f k8s/service-green.yaml
kubectl apply -f k8s/ingress.yaml               # Ingress last — references services by name
```

Verify objects were created:

```bash
kubectl get deployment django-blue django-green
kubectl get ingress django-ingress
```

> **Note:** Deployment pods will show `0/1 Ready` at this point — the image tag (`GIT_SHA`) is
> still a placeholder and will be resolved by the CD pipeline on the first push (section 8).
> Do not run `kubectl rollout status` here; wait until after section 8 completes.

> **Note on GKE Autopilot:** When pods first schedule, Autopilot provisions nodes on demand —
> this can take several minutes. The pod may appear stuck briefly before reaching `Running`.

> **Note:** Each Deployment includes an init container that runs Django DB migrations before the
> app starts. If Cloud SQL is unreachable (private IP not yet peered, or DB not ready), pods will
> hang in `Init:0/1` state — check Cloud SQL status in that case.

---

## 7. Configure DNS & TLS

### 7a. Get the load balancer IP

```bash
cd terraform/
terraform output -raw lb_ip
# Example output: 34.120.x.x
```

### 7b. Create the DNS A record

Point your custom domain to the LB IP in your domain registrar's DNS settings
(e.g., Cloudflare, Namecheap, Google Domains).

> **Note:** This is the only step in this guide that requires a registrar web UI — the exact
> interface depends on your registrar. Create an A record: `<custom-domain>` → `<lb_ip>`.

### 7c. Verify DNS propagation

```bash
dig +short <custom-domain>
# Expected: the LB IP address
```

> **Note:** DNS propagation typically takes a few minutes but can take up to 48 hours depending
> on your registrar's TTL settings. Do not proceed to section 7d until `dig` returns the correct IP.

### 7d. Monitor TLS certificate provisioning (~15 minutes after DNS resolves)

```bash
kubectl describe managedcertificate talana-ssl-cert
# Look for:  Status: Active
# While provisioning you will see: Status: Provisioning
```

### 7e. Verify HTTPS

```bash
curl -I https://<custom-domain>/healthz/
# Expected: HTTP/2 200
```

> **Note:** While the certificate is provisioning, the app is HTTP-accessible at
> `http://<lb_ip>/healthz/` — this is expected.

---

## 8. First Deployment — Push to main

Before pushing, configure the required GitHub Actions secrets in your repository
(**Settings → Secrets and variables → Actions → New repository secret**):

| Secret name | Value |
|-------------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `WIF_PROVIDER` | `terraform output -raw wif_provider_name` |
| `GCP_SA_EMAIL` | `terraform output -raw github_sa_email` |
| `GKE_CLUSTER` | `terraform output -raw cluster_name` |
| `GKE_REGION` | Your GCP region (e.g. `us-central1`) |

> **Dependency:** The WIF pool and service account are provisioned by `terraform apply` (step 4).
> GitHub secrets must be set before the first push triggers CD.

> **Important:** Do not push to `main` before section 6 is complete. The CD pipeline's slot
> detection step (`scripts/detect-slot.sh`) requires `django-ingress` to exist in the cluster —
> it will fail with an error if the Ingress object is not yet applied.

Trigger the pipeline:

```bash
git push origin main
```

Track the run:

```
https://github.com/<owner>/<repo>/actions
```

See the **"What to Expect"** section below for a full description of each pipeline stage.

---

## 9. Verify the Live Application

After the first CD pipeline run completes, verify the deployment:

```bash
# Confirm pods are running (first CD run resolves the GIT_SHA placeholder)
kubectl rollout status deployment/django-blue
kubectl rollout status deployment/django-green

# HTTP health check via LB IP (always available)
curl http://<lb_ip>/healthz/

# HTTPS health check via domain (once cert is Active)
curl https://<custom-domain>/healthz/

# Confirm which slot is currently serving traffic
kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'
# Output: django-blue-svc or django-green-svc
```

---

## What to Expect: Observing a Full CD Cycle (FR34)

When a commit is pushed to `main`, the `cd.yml` GitHub Actions workflow executes these stages
in sequence. Estimated total cycle time: **~5–10 minutes** (NFR2).

1. **Trigger** (~immediate)
   Push to `main` starts the `cd.yml` workflow. Visible in the Actions tab immediately.

2. **OIDC Authentication** (~5–10s)
   `google-github-actions/auth` exchanges the GitHub OIDC token for short-lived GCP credentials
   via Workload Identity Federation. No static service account keys are stored anywhere.

3. **Docker Build & Push** (~2–4 min)
   Image built from `app/Dockerfile` and pushed to Artifact Registry tagged with the full
   40-character git SHA:
   ```
   us-central1-docker.pkg.dev/<project>/talana-artifact-registry/django:<sha>
   ```

4. **Slot Detection (`scripts/detect-slot.sh`)** (~5–10s)
   Reads `kubectl get ingress django-ingress` to determine the currently active slot
   (`blue` or `green`). Derives the inactive slot — this is the deployment target.

5. **Deploy to Inactive Slot** (~1–2 min)
   `kubectl set image deployment/django-<inactive-slot> app=<new-image>` is applied.
   `kubectl rollout status` blocks until the new pods are running and ready.

6. **Smoke Test (`scripts/smoke-test.sh`)** (~20–30s)
   An ephemeral pod is launched inside the cluster. The script resolves the service's ClusterIP
   (`kubectl get svc django-<slot>-svc`) and curls `http://<clusterip>/healthz/`, expecting
   HTTP 200. If the smoke test fails, the pipeline exits non-zero and **traffic is not switched**.

7. **Traffic Switch** (<30s, NFR3)
   `kubectl patch ingress django-ingress` updates `spec.defaultBackend.service.name` to the
   previously-inactive slot. Live traffic shifts atomically. GCP LB propagates the change
   in under 30 seconds (NFR3).

8. **Release Tag** (~5s)
   A GitHub Release is created tagged with the deployed commit SHA for traceability.

> **Note:** The previous slot remains running after the traffic switch and is available for
> instant rollback — see the Rollback Procedure section below.

---

## Rollback Procedure

### Overview

The Blue/Green deployment model keeps both slots (`blue` and `green`) running at all times. Only the **inactive** slot's Deployment image is updated during a new deployment (story 4.2). The currently-live slot is never touched.

This means rollback requires **no new Docker image build** and **no `kubectl apply`** of any manifest. The previous slot's Deployment is already running and healthy. Rollback is a pure Ingress pointer change — only `spec.defaultBackend.service.name` in `django-ingress` needs to be updated. The GCP load balancer propagates the change in under 30 seconds (NFR12/NFR3).

---

### Step 1 — Detect the current active slot

```bash
kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'
```

Output will be `django-blue-svc` or `django-green-svc`. The slot embedded in the service name is the **currently live** slot. The other slot is the previous (rollback target).

**Example:** if the output is `django-green-svc`, the current slot is `green` and the previous slot is `blue`.

---

### Step 2 — Re-patch Ingress to the previous slot

Replace `<SLOT>` with `blue` or `green` (whichever was active **before** the problematic deployment):

```bash
kubectl patch ingress django-ingress \
  --type=merge \
  -p '{"spec":{"defaultBackend":{"service":{"name":"django-<SLOT>-svc"}}}}'
```

**Example** (rolling back to `blue`):

```bash
kubectl patch ingress django-ingress \
  --type=merge \
  -p '{"spec":{"defaultBackend":{"service":{"name":"django-blue-svc"}}}}'
```

Expected output: `ingress.networking.k8s.io/django-ingress patched`

---

### Step 3 — Verify

```bash
kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'
```

Expected output: `django-<SLOT>-svc` (matching the slot you patched to).

---

### Make shorthand

The above patch + verify steps are wrapped in a single Make target:

```bash
make rollback SLOT=<previous-slot>
```

**Example:**

```bash
make rollback SLOT=blue
```

The target validates that `SLOT` is provided, runs the `kubectl patch`, and prints the resulting backend service name for confirmation.

If `SLOT` is omitted, Make prints a descriptive error and exits non-zero:

```
$ make rollback
Makefile:40: *** SLOT is required. Usage: make rollback SLOT=blue or make rollback SLOT=green.  Stop.
```

If an invalid `SLOT` value is provided (anything other than `blue` or `green`), Make also exits non-zero:

```
$ make rollback SLOT=purple
Makefile:43: *** Invalid SLOT value "purple". Must be blue or green.  Stop.
```

---

### Timing

The full operator cycle — detect current slot → patch → verify — completes in under 30 seconds (NFR12). The `kubectl patch` API call itself is sub-second. GCP load balancer propagation is the dominant factor and is well within the 30-second budget. No polling or waiting is required; run the verify command once and the backend will reflect the updated value.

---

## Teardown

To destroy all provisioned resources:

```bash
# Remove K8s resources first — allows GCP LB and NEGs to be cleaned up
kubectl delete -f k8s/

# Wait for the LB backend services to be fully released before Terraform destroy.
# Poll until the ingress address clears (typically 60–120 seconds):
until ! kubectl get ingress django-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q .; do
  echo "Waiting for LB to release..."; sleep 15
done
echo "LB released. Proceeding with terraform destroy."

# Destroy all Terraform-managed GCP resources
cd terraform/
terraform destroy
# Type 'yes' when prompted — never use -auto-approve locally
```

> **Note:** `terraform destroy` does NOT remove the GCS state bucket (`talana-state-bucket`)
> because it was created outside of Terraform by `scripts/bootstrap-state.sh`.
> Verify the bucket contains no state you want to keep before removing it:
>
> ```bash
> gsutil ls -r gs://talana-state-bucket/
> # Confirm the bucket is empty or the state is no longer needed, then:
> gsutil rm -r gs://talana-state-bucket
> ```
