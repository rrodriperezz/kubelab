# kubelab

[![ci](https://github.com/rrodriperezz/kubelab/actions/workflows/ci.yml/badge.svg)](https://github.com/rrodriperezz/kubelab/actions/workflows/ci.yml)

A production-style Kubernetes platform you can rebuild from zero with one command. Terraform and Helm install ingress-nginx, cert-manager with TLS, and metrics-server with autoscaling on a three-node k3d cluster. A hardened sample app and a seven-check smoke test prove it all works, on every push.

```bash
make up     # cluster + platform, from zero to ready
make test   # 7 checks: nodes, pods, metrics, issuer, certificates, ingress, HPA
make down   # back to zero
```

Requires Docker, [k3d](https://k3d.io) v5.7+, Terraform 1.9+, kubectl and curl.

## What you get

| Layer | Component | Why it is there |
|---|---|---|
| Cluster | k3d: 1 server, 2 agents, local registry | Real multi-node scheduling, no cloud bill |
| Ingress | ingress-nginx as a DaemonSet with hostPort | Every node answers, the way a cloud load balancer expects |
| TLS | cert-manager, ClusterIssuer and a wildcard certificate | New hosts get HTTPS with no extra issuance |
| Metrics | metrics-server and a CPU-based HPA | Autoscaling is tested, not assumed |
| Sample app | nginx-unprivileged pinned by digest | Shows the security baseline every workload should meet |

## Security baseline on the sample app

- Runs as non-root (UID 101) with a read-only root filesystem.
- All Linux capabilities dropped, privilege escalation blocked.
- No service account token mounted.
- Image pinned by digest, so every node runs the same binary.
- CPU and memory requests and limits on every container, platform charts included.

## CI

Every push and pull request runs three jobs:

1. **lint:** `terraform fmt` and `validate`, shellcheck and yamllint.
2. **cluster:** creates the cluster, applies the platform, runs the smoke test and tears everything down. If a check fails, it prints nodes, pods, certificates and HPA state before cleanup.
3. **security:** checkov on the Terraform code, trivy config scan (HIGH and CRITICAL fail the build) and gitleaks over the full git history.

## Design decisions

- **Two-pass apply.** `kubernetes_manifest` resolves its schema at plan time, so the cert-manager CRDs must exist before Terraform can plan the ClusterIssuer. `depends_on` orders the apply, not the plan.
- **Explicit kubeconfig context.** The providers never trust the current context, so an apply cannot land on whatever other cluster happens to be selected.
- **Atomic Helm releases.** A failed install rolls back instead of leaving a half-installed release the next apply cannot reconcile.
- **Pinned everything.** Terraform, k3d, chart versions, provider hashes (`.terraform.lock.hcl`), the gitleaks binary and the app image. A new upstream release cannot break the build overnight.
- **Local-only concessions are marked.** The self-signed issuer, `--kubelet-insecure-tls` and the disabled HTTPS redirect are commented with what production would do instead.

## Layout

```
cluster/k3d-config.yaml   declarative cluster definition
terraform/                platform: namespaces, Helm releases, issuers, sample app
terraform/values/         Helm values per chart
tests/smoke.sh            end-to-end checks with bounded retries
```

Run `make help` for every target.
