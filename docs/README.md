# talana SRE Challenge

**Live Application:** https://talana.nacholar.com/
**Health Check:** https://talana.nacholar.com/healthz/

---

## Overview

This project demonstrates a production-grade GCP infrastructure for a Django application, built for the Talana SRE challenge. It provisions all cloud resources with Terraform (5 custom modules for networking, IAM, GKE, Cloud SQL, and Artifact Registry), runs the application on GKE Autopilot, and delivers zero-downtime deployments via a Blue/Green pipeline in GitHub Actions. Key GCP services used: GKE Autopilot, Cloud SQL (PostgreSQL), Secret Manager, Artifact Registry, GCP HTTPS Load Balancer, and Workload Identity Federation.

---

## Architecture Highlights

- **GKE Autopilot** — No node pool management; Google manages worker nodes entirely.
- **Workload Identity Federation** — GitHub Actions authenticates to GCP via OIDC; zero long-lived service account keys anywhere in the CD pipeline (NFR5).
- **Kubernetes Workload Identity** — Django pods obtain GCP credentials at runtime via the pod service account; zero static credentials in Kubernetes manifests or Dockerfiles (NFR7).
- **Blue/Green deployments via Ingress backend swap** — The inactive slot is updated and smoke-tested before Ingress traffic switches; zero-downtime deploys with instant rollback capability.
- **Secret Manager SDK direct** — The application fetches DB credentials and Django SECRET_KEY at pod startup via the Python Secret Manager client; no sidecar, no CSI driver.
- **Init container for DB migrations** — A `db-migrate` init container runs before the app container starts, preventing Django from serving traffic against an unmigrated schema (NFR13).
- **GCP-managed SSL certificate** — TLS is provisioned and renewed automatically by GCP; no manual certificate management (NFR10).
- **All private networking** — GKE nodes have no public IPs; Cloud SQL is reachable only via private IP within the VPC (NFR6).

---

## Quick Start

```bash
# See docs/deployment-guide.md for the full step-by-step guide
git clone https://github.com/nacholar/talana
cd talana
# Follow docs/deployment-guide.md
```

[Full deployment guide](deployment-guide.md)

---

## Observe CI/CD in Action

| Pipeline | Trigger | Link |
|----------|---------|------|
| **CI** | Every pull request | [ci.yml runs](https://github.com/nacholar/talana/actions/workflows/ci.yml) |
| **CD** | Push to `main` | [cd.yml runs](https://github.com/nacholar/talana/actions/workflows/cd.yml) |

**CI** (`ci.yml`) — Lints the Dockerfile (hadolint), runs Django tests, validates Terraform, and verifies the Docker image builds successfully. Blocks PR merges on failure.

**CD** (`cd.yml`) — Authenticates to GCP via OIDC WIF, builds and pushes a SHA-tagged Docker image to Artifact Registry, deploys to the inactive Blue/Green slot, runs a smoke test, and switches Ingress traffic if the smoke test passes.

---

## Repository Structure

```
terraform/      — GCP infrastructure (5 custom modules + root LB static IP)
k8s/            — Kubernetes manifests (Blue/Green deployments, Ingress, TLS)
app/            — Django application (Secret Manager, /healthz/, WhiteNoise)
.github/        — CI/CD pipelines (ci.yml + cd.yml)
scripts/        — Shell scripts extracted from pipeline YAML
docs/           — This deployment guide, architecture, cost estimate
```

---

## Security Posture

| Control | Implementation |
|---------|---------------|
| Zero long-lived GCP service account keys | GitHub Actions uses OIDC WIF — no JSON key files |
| Zero static credentials in Kubernetes | Kubernetes Workload Identity — pods impersonate a KSA bound to a GSA |
| Zero secrets in source code or Dockerfiles | Secret Manager SDK fetches all secrets at pod startup |
| All containers run non-root | UID 1000, `runAsNonRoot: true`, `allowPrivilegeEscalation: false` |
| Least-privilege pod service account | `django-ksa` is bound to a GSA with only `cloudsql.client` + `secretmanager.secretAccessor` |
| All internet traffic encrypted | GCP-managed TLS cert on HTTPS Load Balancer; HTTP redirects to HTTPS |
| Private networking | GKE nodes have no public IPs; Cloud SQL is accessible via private IP only |
