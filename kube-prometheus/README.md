# 📈 Monitoring Overview

<p align="center">
  <img src="./Monitoring.png" alt="Monitoring Architecture" width="80%" style="padding:20px; border-radius:10px;" />
</p>

## 🧩 Overview

Monitoring in this homelab is powered by **kube-prometheus-stack**, which bundles together **Prometheus**, **Alertmanager**, **Grafana**, and all the related CRDs (PodMonitor, ServiceMonitor, etc.).  
The goal here is to have a **completely self-contained monitoring solution** capable of collecting, visualizing, and alerting on both cluster-level and application-level metrics — all running locally, with no dependency on any external cloud service.

The entire stack was deployed via **Helm**, with a couple of small adjustments to better fit my self-hosted environment and network setup.

---

## 🔭 Prometheus Setup

Prometheus is responsible for scraping metrics across the cluster.  
The **Prometheus Operator** automatically discovers metric sources via the implemented **PodMonitor** and **ServiceMonitor** resources.

Custom monitors were added for several components, including:

| Target         | Type             | Location                                                     |
| -------------- | ---------------- | ------------------------------------------------------------ |
| CloudNativePG  | `PodMonitor`     | [`../cloudnativepg/prometheus`](../cloudnativepg/prometheus) |
| Longhorn       | `ServiceMonitor` | `../longhorn/prometheus`                                     |
| Traefik        | `ServiceMonitor` | `../traefik/prometheus`                                      |
| Node Exporters | `DaemonSet`      | Part of kube-prometheus-stack                                |

The default Prometheus rules and alerts from the chart were extended with a few custom alerts specific to this setup — for example, **disk utilization on Longhorn volumes** and **Postgres replication lag**.

---

## 📊 Grafana

Visualization is handled by **Grafana**, which comes bundled with the kube-prometheus-stack deployment.

The following dashboards are currently in use:

- [CloudNativePG Dashboard](https://grafana.com/grafana/dashboards/20417-cloudnativepg/)
- Node and Cluster Metrics
- Longhorn Volume Health
- Traefik Request and Latency Metrics

All dashboards are automatically provisioned using the Helm chart’s `dashboards` and `datasources` sections.  
User authentication is handled internally through `admin` credentials stored in a **sealed secret**.

> 💡 **Note:** Grafana is not publicly exposed — it’s only accessible through the **Tailscale VPN** or via the internal Traefik route (`grafana.homelab.local`).

---

## 🚨 Alertmanager

Alerts are routed through **Alertmanager**, which is part of the same Helm release.  
Currently, it is configured to send notifications through:

- **Telegram Bot** (via a Kubernetes secret)
- **Email** (optional, disabled by default)

In the future, I plan to integrate Alertmanager with **n8n** for event-based automation — for example, triggering messages or generating incident tickets automatically.

---

## 📂 Files

| Path           | Description                                              |
| -------------- | -------------------------------------------------------- |
| `values.yaml`  | Helm values file for kube-prometheus-stack configuration |
| `alerts/`      | Custom alerting rules (PrometheusRule CRDs)              |
| `dashboards/`  | Custom Grafana dashboards (JSON files)                   |
| `secrets/`     | Encrypted secrets for Grafana and Alertmanager           |
| `podmonitors/` | PodMonitor definitions for custom apps                   |
| `README.md`    | This documentation file                                  |

---

## 🧑‍💻 Author

**Juan Campos**  
DevOps & Systems Designer — Building resilient, self-hosted cloud infrastructure for learning, experimentation, and production-ready prototypes.  
Industrial Designer turned homelab nerd turned DevOps engineer.

[LinkedIn](https://www.linkedin.com/in/juan-ignacio-campos-ruiz-3692212b2/)

---

> 🔒 **Note:** All sensitive data (tokens, passwords, private keys) are encrypted or managed externally.  
> The monitoring stack is entirely self-hosted and accessible only through the **Tailscale network**.

---
