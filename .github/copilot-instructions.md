<!-- .github/copilot-instructions.md - guidance for AI coding agents -->
# Copilot / AI Agent Instructions for the Homelab Repo

Purpose
- Provide concise, actionable rules so AI coding agents can be productive immediately in this repository.

Quick architecture summary
- This is a GitOps-style homelab for a k3s Kubernetes cluster. Major pieces:
  - Networking: Tailscale (tailnet + proxy groups) for internal connectivity and HA exposure.
  - Ingress: Traefik is used as the cluster ingress/load-balancer.
  - Storage: Longhorn for block volumes and MinIO as an S3-compatible object store.
  - Databases: CloudNativePG (CNPG) operator manages Postgres clusters; Barman Cloud Plugin sends backups to MinIO.
  - Observability: Prometheus Operator + Grafana (+ Alertmanager); PodMonitors and PrometheusRules live under `*/prometheus` folders.
  - Secrets: Hashicorp Vault — secrets are managed externally; do not add plaintext secrets to the repo.
  - GitOps: ArgoCD manifests live under `argocd/` and are the primary deployment mechanism.

Repo patterns to know
- Kustomize-first: Most deployments use `kustomization.yaml` (see many subfolders including `deployment/`, `cloudnativepg/`, `cloud/` etc.). Use `kustomize build` or `kubectl apply -k` when rendering/applying locally.
- CRDs & Operators: CNPG operator manifests and CRs are under `cloudnativepg/` (`operator/`, `cluster/`, `barmancloudplugin/`). Changes to operator values (e.g., `cloudnativepg/operator/values.yaml`) affect how clusters are created.
- GitOps via ArgoCD: `argocd/apps/` and `argocd/appsets/` contain application definitions. The source of truth is this repo; do not attempt to modify cluster state outside of ArgoCD unless debugging.
- Terraform: `terraform/` contains provisioning scripts and cloud-init templates. Use `terraform` commands from that directory.

Developer workflows & cli examples
- Render a kustomize overlay locally:
  - `kustomize build ./cloudnativepg/cluster` or `kubectl kustomize ./cloudnativepg/cluster`
- Apply a set of manifests for quick testing (dev cluster only):
  - `kubectl apply -k ./deployment` or `kubectl apply -k ./cloudnativepg/operator` (use with caution; production changes follow ArgoCD)
- Validate Prometheus rules and PodMonitors by rendering and inspecting `*/prometheus/prometheusrule.yaml` and `*/prometheus/*` resources.
- Inspect a Helm chart (local): `helm template ./minio/chart -f ./minio/values.yaml`
- Terraform: `cd terraform && terraform init && terraform plan` (sensitive vars are in `terraform.tfvars` — do not commit secrets)

Project-specific conventions
- No plaintext secrets in repo: Vault is authoritative — do not create or suggest new secret files in the repository.
- Keep GitOps parity: prefer changing files under `argocd/` or service folders and let ArgoCD reconcile.
- Kustomize naming: many kustomizations assume relative path bases; preserve relative references when moving files.
- Backup flow: CloudNativePG uses Barman Cloud Plugin; the `barmancloudplugin/` folder contains the plugin deployment and `cluster/cluster.yaml` is modified to enable it.

Integration points and cross-component flows (examples)
- Postgres backups: CNPG -> Barman Cloud Plugin -> MinIO (`cloudnativepg/barmancloudplugin/*` and `minio/`)
- Monitoring: CNPG exposes PodMonitor resources discovered by Prometheus Operator (`cloudnativepg/prometheus/`) and alert rules in `cloudnativepg/prometheus/prometheusrule.yaml`.
- Ingress & networking: Traefik + Tailscale Proxy Groups provide stable IPs for services; check `tailscale/` and `traefik/` folders for proxy and ingress examples.

When you edit code or manifests
- Small changes (docs, minor patches): open a branch and create a PR. Keep changes scoped and include which ArgoCD app will pick them up.
- Operator/CRD changes: update operator `values.yaml` and relevant CR manifests under `cloudnativepg/`, then push; test in a staging environment before production.
- Do not add secrets or credentials; instead, reference Vault paths and document required secret names and shapes.

Files to reference while working
- Root README: `README.md` — big-picture architecture and service list.
- GitOps apps: `argocd/apps/`, `argocd/appsets/` — where deployments are declared.
- CNPG operator & cluster: `cloudnativepg/operator/`, `cloudnativepg/cluster/`, `cloudnativepg/barmancloudplugin/`.
- Observability: `kube-prometheus/` and `observability-stack/` and `*/prometheus/` subfolders across services.
- Storage and object store: `longhorn/`, `minio/`.
- Secrets/values: `hashicorp/vault/` and `vault/` subfolders for service-specific Vault config.

Examples to include in suggestions
- If asked to add a PodMonitor, reference `cloudnativepg/prometheus/podmonitor.yaml` style and place new file under `serviceX/prometheus/`.
- When recommending backup changes, point to `cloudnativepg/barmancloudplugin/objectStore.yaml` for MinIO connection settings.

What NOT to do
- Commit secrets, tokens, or private keys.
- Bypass ArgoCD for normal deployments in the default branch.
- Assume cluster internals are public; many endpoints are reachable only through Tailscale.

Questions & feedback
- If anything in these instructions is unclear or you find repository patterns that contradict these notes, open an issue or ask for clarification in the PR description.

-- End of instructions --
