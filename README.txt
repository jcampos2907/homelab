# 🏡 Homelab Infrastructure Overview

![Homelab Architecture](./Homelab.png)

## 📖 Summary
This repository documents my personal **homelab Kubernetes infrastructure**, designed to replicate a production-grade, high-availability DevOps environment.  
The setup demonstrates proficiency in container orchestration, storage management, networking, observability, and secure service exposure using modern open-source tools.

---

## 🧩 Core Components

### ⚙️ Kubernetes Cluster
- **Distribution:** K3s (lightweight Kubernetes)
- **Topology:** 3-node HA cluster with embedded etcd
- **Control Plane:** Nodes 1-3 (each with 32 GB RAM, 1 TB NVMe SSD, 1 TB SATA SSD)
- **Networking:**  
  - Internal connectivity via **Tailscale mesh VPN**  
  - Nodes and workloads isolated from the public internet  

### 🧠 Control & Networking
- **Tailscale** handles private networking, node discovery, and external access to the cluster.  
- **Traefik (HA pair)** serves as the ingress controller and reverse proxy.  
- **Cert-Manager** automatically issues and renews TLS certificates for all internal and external services.

---

## 🗄️ Storage & Data Management
- **Longhorn** provides distributed, replicated block storage across all nodes.  
- **MinIO** runs in tenant mode as an S3-compatible object store.  
- **CloudNativePG** (CNPG) manages PostgreSQL clusters with:  
  - High-availability replication  
  - Scheduled S3 backups to MinIO using Barman  
  - Async replication between clusters for fault tolerance

---

## 🔍 Observability Stack
- **Prometheus Operator** for metrics collection  
- **Grafana** for dashboards and visualizations  
- **Alertmanager** for notifications (e.g., Telegram webhooks)  
- **Loki** (planned integration) for centralized log aggregation

---

## 🔐 Security
- All cluster communication runs within the **Tailscale** network.  
- No public Kubernetes API exposure.  
- SSL/TLS certificates managed via **cert-manager**.  
- Secrets managed externally (Vault + SOPS) — none stored in plaintext within the repo.

---

## 🧰 Supporting Services
- **Vault** for dynamic secrets and credentials  
- **n8n** for workflow automation (exposed only via Tailscale or VPN tunnels)  
- **Pi-hole** (optional) for DNS filtering and metrics  
- **Cloudflare Tunnels** optionally expose selected services (Grafana, Vault UI) securely via HTTPS

---

## 🧮 Infrastructure Summary
| Layer | Tool / Service | Purpose |
|-------|----------------|----------|
| Networking | **Tailscale** | Secure mesh connectivity |
| Ingress | **Traefik** | Reverse proxy + SSL termination |
| Storage | **Longhorn** | Distributed volume management |
| Object Store | **MinIO** | S3-compatible storage |
| Database | **CloudNativePG** | Postgres HA and backups |
| Monitoring | **Prometheus / Grafana** | Metrics and dashboards |
| Backups | **Barman via MinIO** | CNPG scheduled backups |
| Automation | **n8n** | Event-based workflows |
| Secrets | **Vault / SOPS** | Encrypted secret management |

---

## 🚀 Key Capabilities
- Fully declarative **GitOps-ready** environment (ArgoCD / Flux-compatible)  
- High-availability Postgres with **multi-cluster failover**  
- Encrypted, self-healing **persistent storage**  
- Secure, DNS-based service exposure via **Tailscale** and **Cloudflare Tunnels**  
- Modular design — supports scaling nodes or services independently  

---

## 📄 Repository Contents
| Path | Description |
|------|--------------|
| `./Homelab.png` | Architecture diagram |
| `manifests/` | Core Kubernetes YAML files |
| `helm/` | Helm chart overrides and values |
| `monitoring/` | Prometheus and Grafana configurations |
| `storage/` | Longhorn and CNPG manifests |
| `networking/` | Traefik, Tailscale, and DNS configs |
| `automation/` | n8n workflows and auxiliary jobs |

---

## 🧑‍💻 Author
**Juan Campos**  
DevOps & Systems Designer — Building resilient, self-hosted cloud infrastructure for learning, experimentation, and production-ready prototypes.  

---

> **Note:** All sensitive data (tokens, passwords, private keys) are encrypted or managed externally.  
> The domains and endpoints shown here are non-public and accessible only via VPN.

---
