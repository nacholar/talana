# GCP Cost Estimate

## Summary

Estimated total monthly cost for this demo deployment: **~$120–140/month** (us-central1, minimal traffic).

---

## Resource Cost Breakdown

| Resource | GCP SKU / Type | Estimated Monthly Cost |
|----------|---------------|----------------------|
| GKE Autopilot | Cluster management fee | ~$73/month ($0.10/hr) |
| GKE Autopilot | Pod resources — 2 pods × 250m CPU + 512Mi RAM | ~$21/month |
| Cloud SQL PostgreSQL | `db-f1-micro`, 10 GB SSD storage | ~$7–10/month |
| Cloud SQL | Network egress (private IP, minimal traffic) | ~$0/month |
| Artifact Registry | Storage (a few Docker images, <1 GB) | ~$0.10–1/month |
| GCP HTTP(S) Load Balancer | 2 forwarding rules + minimal ingress traffic | ~$18/month |
| Static global IP address | 1 in-use global IP | ~$7/month ($0.01/hr) |
| Cloud NAT | Port usage + minimal processing | ~$1–2/month |
| Secret Manager | API calls at pod startup (minimal volume) | <$0.10/month |
| GCS State Bucket | Terraform state files (<1 MB) | <$0.01/month |
| GCP-managed SSL certificate | No charge | $0 |
| **Total Estimate** | | **~$120–140/month** |

> Costs are estimates based on GCP pricing as of Q1 2026. Actual costs depend on traffic volume and pod scheduling patterns. For a demo with minimal traffic, costs will be at the lower end of each range.

---

## Notes & Assumptions

- **GKE Autopilot billing model** — Charged per pod vCPU-hour and GB-hour, not per node. The cluster management fee (~$73/month) is fixed regardless of workload.
- **Pod resources** — 2 Django pods running continuously (Blue + Green slots; both are deployed and running, but only the active slot receives traffic). Each pod requests 250m CPU and 512Mi RAM. During a deploy, the inactive slot's `db-migrate` init container temporarily adds a third 250m CPU / 512Mi RAM request for the duration of the migration run.
  - 2 × 250m CPU = 0.5 vCPU @ ~$0.0483/vCPU-hour ≈ $14/month
  - 2 × 512Mi = 1 GiB RAM @ ~$0.00650/GB-hour ≈ $5/month
- **Cloud SQL `db-f1-micro`** — Smallest available shared-core instance, suitable for a demo workload. Price includes 10 GB SSD storage.
- **Load Balancer** — Two forwarding rules (HTTP and HTTPS) account for the majority of the LB cost at low traffic. Ingress data processing is negligible for a demo.
- **Region** — All resources provisioned in `us-central1`. Pricing varies by region.
- **Network egress** — Assumes <1 GB/month external egress. Cloud SQL uses private IP so inter-service traffic is not billed as egress.
- **Idle slots** — Both Blue and Green deployments are always running; only the active slot receives live traffic at any given time. The inactive slot sits warm and ready for the next deploy.

---

## Cost Optimization Opportunities

The following optimisations are not implemented in this challenge (scope intentionally limited) but would reduce costs in a production environment:

- **Scale-to-zero** — GKE Autopilot can scale idle pods to zero. For a demo with no traffic overnight, pod costs approach $0. Requires HPA or KEDA configuration.
- **Delete Cloud SQL when idle** — `db-f1-micro` is already the smallest available Cloud SQL tier. For a demo that is only used periodically, stopping the instance when not in use eliminates the ~$7–10/month instance cost entirely.
- **Single active slot** — Running only the active pod (stopping the idle slot) would halve pod resource costs (~$10/month saving), at the expense of keeping a warm standby.
- **HPA (Horizontal Pod Autoscaler)** — Scale pod replicas down to 1 during low-traffic periods.
- **Cloud CDN** — Would reduce LB egress costs at scale by caching static assets (WhiteNoise-served files).
- **Committed Use Discounts** — For long-running workloads, 1- or 3-year committed use discounts apply to vCPU and RAM pricing on GKE Autopilot.
