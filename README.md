# terraform-k8s-monitoring

Terraform modules for deploying a full observability stack on Kubernetes. Metrics (Mimir), logs (Loki), traces (Tempo), collection (OpenTelemetry Collector), dashboards and alerts (Grafana via kube-prometheus-stack). Works on any Kubernetes cluster — EKS, GKE, AKS, or bare metal.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Module Reference](#module-reference)
  - [cert-manager](#cert-manager)
  - [mimir](#mimir)
  - [prometheus](#prometheus)
  - [loki](#loki)
  - [tempo](#tempo)
  - [otel-collector](#otel-collector)
  - [prometheus-rules](#prometheus-rules)
  - [grafana-rules](#grafana-rules)
- [Common Recipes](#common-recipes)
- [Storage Backends](#storage-backends)
- [Architecture](#architecture)

---

## Prerequisites

- A running Kubernetes cluster with a valid `kubeconfig`
- `kubectl` configured and pointing at the target cluster
- Terraform >= 1.4 or OpenTofu >= 1.4
- The Terraform Helm and Kubernetes providers configured (see [Quick Start](#quick-start))
- Buckets or containers pre-created if using cloud storage backends — this module does not create them

---

## Quick Start

This example deploys the full stack with local disk storage. No cloud credentials required. Data lives on the pod filesystem — suitable for development, evaluation, and blog-post walkthroughs.

**`providers.tf`**

```hcl
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
```

**`main.tf`**

```hcl
module "cert_manager" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/cert-manager"
}

module "mimir" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/mimir"
}

module "loki" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/loki"
  loki = {
    create_namespace = false
  }
}

module "tempo" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/tempo"
  tempo = {
    create_namespace = false
  }
}

module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"
  prometheus = {
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id
    loki_datasource_url    = module.loki.datasource_url
    tempo_datasource_url   = module.tempo.datasource_url
    grafana_ingress = {
      enabled    = true
      host       = "grafana.YOUR_DOMAIN"
      class_name = "nginx"
    }
  }
}

module "otel" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/otel-collector"
  otel = {
    create_namespace = false
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    loki_endpoint    = module.loki.datasource_url
  }
}

module "prometheus_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus-rules"
  prometheus_rules = {
    prometheus_release_id = module.prometheus.helm_release_id
  }
}

module "grafana_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/grafana-rules"
  grafana_rules = {}
}
```

**Deploy:**

```bash
terraform init
terraform apply
```

Grafana will be available at `https://grafana.YOUR_DOMAIN`. The default credentials are `admin` / `prom-operator`.

---

## Module Reference

### cert-manager

Installs cert-manager and creates a self-signed `ClusterIssuer`. Other modules reference this issuer in their ingress TLS annotations.

```hcl
module "cert_manager" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/cert-manager"

  cert_manager = {
    chart_version       = "v1.19.1"
    namespace           = "cert-manager"
    create_namespace    = true
    cluster_issuer_name = "selfsigned-cluster-issuer"
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"v1.19.1"` | cert-manager Helm chart version |
| `namespace` | `"cert-manager"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `cluster_issuer_name` | `"selfsigned-cluster-issuer"` | Name of the ClusterIssuer to create — must match the `cert-manager.io/cluster-issuer` annotation in other modules |

No notable outputs.

---

### mimir

Installs Grafana Mimir as the metrics storage and query backend. Prometheus writes metrics here via remote_write. Grafana queries here via a Prometheus-compatible datasource.

```hcl
module "mimir" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/mimir"

  mimir = {
    namespace        = "monitoring"
    retention_period = "30d"
    tenant_id        = "anonymous"
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"5.6.0"` | Mimir distributed Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `retention_period` | `"30d"` | How long to keep metrics |
| `tenant_id` | `"anonymous"` | Value sent in `X-Scope-OrgID` header by Prometheus and Grafana |
| `replicas` | `1` | Number of replicas for each Mimir component |
| `ingress_enabled` | `false` | Expose Mimir via an Ingress |
| `ingress_host` | `""` | Hostname for the Mimir ingress (required when `ingress_enabled = true`) |
| `ingress_class_name` | `"nginx"` | Ingress class |
| `ingress_tls_secret` | `""` | TLS secret name |
| `storage.backend` | `"local"` | Storage backend: `local`, `s3`, `gcs`, or `azure` |
| `service_account_annotations` | `{}` | Annotations for IRSA / Workload Identity |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 100m CPU / 512Mi memory request, 2 CPU / 4Gi memory limit.

**Outputs:**

| Output | Description |
| --- | --- |
| `remote_write_endpoint` | Prometheus `remote_write` URL — wire into the prometheus module |
| `query_frontend_endpoint` | Grafana datasource URL — wire into the prometheus module |
| `tenant_id` | The configured tenant ID — wire into the prometheus module |
| `namespace` | Namespace where Mimir is deployed |

---

### prometheus

Installs kube-prometheus-stack: Prometheus, Grafana, and Alertmanager. Configures remote_write to Mimir and adds Loki and Tempo as Grafana datasources automatically when their URLs are supplied.

```hcl
module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id
    loki_datasource_url    = module.loki.datasource_url
    tempo_datasource_url   = module.tempo.datasource_url
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"75.2.0"` | kube-prometheus-stack Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `grafana_enabled` | `true` | Deploy Grafana |
| `alertmanager_enabled` | `true` | Deploy Alertmanager |
| `mimir_remote_write_url` | `""` | Mimir remote_write URL — use `module.mimir.remote_write_endpoint` |
| `mimir_datasource_url` | `""` | Mimir query URL — use `module.mimir.query_frontend_endpoint` |
| `mimir_tenant_id` | `"anonymous"` | Tenant ID for `X-Scope-OrgID` header |
| `loki_datasource_url` | `""` | Loki URL — use `module.loki.datasource_url` |
| `tempo_datasource_url` | `""` | Tempo URL — use `module.tempo.datasource_url` |
| `storage_size` | `"20Gi"` | PVC size for Prometheus TSDB |
| `storage_class` | `""` | StorageClass name (cluster default if empty) |
| `retention` | `"24h"` | Local TSDB retention (metrics are in Mimir long-term) |
| `grafana_dashboard_imports` | Node Exporter Full (1860) | Grafana.com dashboard IDs to import |
| `extra_dashboards` | `{}` | Additional dashboard JSON — `{ "name.json" = file("...") }` |
| `grafana_ingress` | disabled | Grafana ingress config (see [Enable ingress](#enable-ingress-for-grafana-with-tls)) |
| `prometheus_ingress` | disabled | Prometheus ingress config |
| `alertmanager_ingress` | disabled | Alertmanager ingress config |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 200m CPU / 512Mi memory request, 2 CPU / 2Gi memory limit.

**Outputs:**

| Output | Description |
| --- | --- |
| `grafana_service` | In-cluster Grafana URL |
| `helm_release_id` | Helm release ID — required by prometheus-rules module |
| `namespace` | Namespace where kube-prometheus-stack is deployed |

---

### loki

Installs Grafana Loki for log aggregation. Supports single-binary (default) and scalable (SimpleScalable) deployment modes.

```hcl
module "loki" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/loki"

  loki = {
    namespace        = "monitoring"
    create_namespace = false
    deployment_mode  = "single-binary"
    retention_period = "744h"
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"6.6.0"` | Loki Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `deployment_mode` | `"single-binary"` | `single-binary` or `scalable` |
| `replicas` | `1` | Replica count (single-binary mode) |
| `retention_period` | `"744h"` | Log retention period (31 days) |
| `storage.backend` | `"local"` | Storage backend: `local`, `s3`, `gcs`, or `azure` |
| `service_account_annotations` | `{}` | Annotations for IRSA / Workload Identity |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 100m CPU / 256Mi memory request, 2 CPU / 2Gi memory limit.

**Outputs:**

| Output | Description |
| --- | --- |
| `datasource_url` | Loki URL for Grafana datasource and OTel Collector — `http://loki.monitoring.svc.cluster.local:3100` |
| `namespace` | Namespace where Loki is deployed |

---

### tempo

Installs Grafana Tempo for distributed tracing. Supports monolithic (default) and distributed deployment modes.

```hcl
module "tempo" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/tempo"

  tempo = {
    namespace        = "monitoring"
    create_namespace = false
    deployment_mode  = "monolithic"
    retention        = "720h"
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"1.40.0"` | Tempo Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `deployment_mode` | `"monolithic"` | `monolithic` or `distributed` |
| `replicas` | `1` | Replica count (monolithic mode) |
| `retention` | `"720h"` | Trace retention period (30 days) |
| `storage.backend` | `"local"` | Storage backend: `local`, `s3`, `gcs`, or `azure` |
| `service_account_annotations` | `{}` | Annotations for IRSA / Workload Identity |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 100m CPU / 256Mi memory request, 2 CPU / 2Gi memory limit.

**Outputs:**

| Output | Description |
| --- | --- |
| `datasource_url` | Tempo URL for Grafana datasource |
| `otlp_grpc_endpoint` | OTLP gRPC endpoint for app instrumentation (port 4317) |
| `otlp_http_endpoint` | OTLP HTTP endpoint for app instrumentation (port 4318) |
| `namespace` | Namespace where Tempo is deployed |

---

### otel-collector

Installs the OpenTelemetry Collector (contrib image). Receives OTLP traces, metrics, and logs from your applications and forwards them to Tempo, Mimir, and Loki respectively. Runs as a DaemonSet by default.

```hcl
module "otel" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/otel-collector"

  otel = {
    namespace        = "monitoring"
    create_namespace = false
    mode             = "daemonset"
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    loki_endpoint    = module.loki.datasource_url
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"0.150.0"` | OpenTelemetry Collector Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `mode` | `"daemonset"` | `daemonset` or `deployment` |
| `tempo_endpoint` | `""` | OTLP gRPC endpoint for Tempo — use `module.tempo.otlp_grpc_endpoint` |
| `mimir_endpoint` | `""` | Remote write URL for Mimir — use `module.mimir.remote_write_endpoint` |
| `loki_endpoint` | `""` | Loki push URL — use `module.loki.datasource_url` |
| `image.repository` | `"otel/opentelemetry-collector-contrib"` | Collector image (contrib required for Loki and Mimir exporters) |
| `service_account_annotations` | `{}` | Annotations for IRSA / Workload Identity |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 100m CPU / 128Mi memory request, 500m CPU / 512Mi memory limit.

**Outputs:**

| Output | Description |
| --- | --- |
| `otlp_grpc_endpoint` | OTLP gRPC endpoint your apps send traces to (port 4317) |
| `otlp_http_endpoint` | OTLP HTTP endpoint your apps send traces to (port 4318) |
| `namespace` | Namespace where the collector is deployed |

---

### prometheus-rules

Applies Prometheus alert rules and configures Alertmanager receivers. Must be applied after the prometheus module — pass `module.prometheus.helm_release_id` to enforce ordering.

```hcl
module "prometheus_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus-rules"

  prometheus_rules = {
    namespace             = "monitoring"
    prometheus_release_id = module.prometheus.helm_release_id
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `namespace` | `"monitoring"` | Must match the kube-prometheus-stack namespace |
| `prometheus_release_id` | required | Output from `module.prometheus.helm_release_id` |
| `extra_rules` | `{}` | Additional rule YAML files — `{ "my-app.yaml" = file("...") }` |
| `slack.enabled` | `false` | Send alerts to Slack |
| `slack.webhook_url` | `""` | Slack incoming webhook URL (required when enabled) |
| `slack.channel` | `"#alerts"` | Slack channel |
| `slack.min_severity` | `"warning"` | Minimum severity to forward: `info`, `warning`, or `critical` |
| `pagerduty.enabled` | `false` | Send alerts to PagerDuty |
| `pagerduty.routing_key` | `""` | PagerDuty routing key (required when enabled) |
| `pagerduty.min_severity` | `"critical"` | Minimum severity to page |

No notable outputs.

---

### grafana-rules

Applies Grafana-managed alert rules and configures Grafana contact points (Slack, PagerDuty, webhook, email).

```hcl
module "grafana_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/grafana-rules"

  grafana_rules = {
    namespace = "monitoring"
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `namespace` | `"monitoring"` | Must match the kube-prometheus-stack namespace |
| `extra_rules` | `{}` | Additional rule YAML files — `{ "my-app.yaml" = file("...") }` |
| `slack.enabled` | `false` | Send alerts to Slack |
| `slack.webhook_url` | `""` | Slack incoming webhook URL (required when enabled) |
| `slack.channel` | `"#alerts"` | Slack channel |
| `slack.min_severity` | `"warning"` | Minimum severity: `info`, `warning`, or `critical` |
| `pagerduty.enabled` | `false` | Send alerts to PagerDuty |
| `pagerduty.integration_key` | `""` | PagerDuty integration key (required when enabled) |
| `pagerduty.min_severity` | `"critical"` | Minimum severity to page |
| `webhook.enabled` | `false` | Send alerts to a generic webhook |
| `webhook.url` | `""` | Webhook URL (required when enabled) |
| `webhook.http_method` | `"POST"` | HTTP method |
| `webhook.min_severity` | `"warning"` | Minimum severity |
| `email.enabled` | `false` | Send alerts by email |
| `email.addresses` | `[]` | List of recipient email addresses (required when enabled) |
| `email.min_severity` | `"critical"` | Minimum severity |

No notable outputs.

---

## Common Recipes

### Use S3 for Mimir storage (with IRSA)

Pre-create three S3 buckets before running `terraform apply`. IRSA handles authentication — no access keys needed.

```hcl
module "mimir" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/mimir"

  mimir = {
    namespace        = "monitoring"
    retention_period = "90d"

    storage = {
      backend                = "s3"
      s3_blocks_bucket       = "YOUR_BUCKET_NAME-mimir-blocks"
      s3_ruler_bucket        = "YOUR_BUCKET_NAME-mimir-ruler"
      s3_alertmanager_bucket = "YOUR_BUCKET_NAME-mimir-alertmanager"
      s3_region              = "eu-west-1"
      # s3_access_key and s3_secret_key left empty — IRSA is used instead
    }

    service_account_annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/mimir"
    }
  }
}
```

---

### Use S3-compatible storage (Hetzner, MinIO, Ceph)

Any S3-compatible service works. Set `s3_endpoint` to the service URL, `s3_path_style = true` (required by Hetzner and most non-AWS services), and provide access credentials.

```hcl
module "mimir" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/mimir"

  mimir = {
    namespace        = "monitoring"
    retention_period = "30d"

    storage = {
      backend                = "s3"
      s3_blocks_bucket       = "mimir-blocks"
      s3_ruler_bucket        = "mimir-ruler"
      s3_alertmanager_bucket = "mimir-alertmanager"
      s3_region              = "eu-central"          # Hetzner region, or "us-east-1" for MinIO
      s3_endpoint            = "https://YOUR_BUCKET_NAME.fsn1.your-objectstorage.com"  # Hetzner example
      s3_path_style          = true                  # required for Hetzner, MinIO, Ceph
      s3_insecure            = false                 # set true only for plain HTTP endpoints
      s3_access_key          = "YOUR_ACCESS_KEY"
      s3_secret_key          = "YOUR_SECRET_KEY"
    }
  }
}
```

The same `s3_endpoint`, `s3_path_style`, and `s3_insecure` variables are available on `modules/loki` and `modules/tempo`:

```hcl
module "loki" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/loki"

  loki = {
    storage = {
      backend          = "s3"
      s3_chunks_bucket = "loki-chunks"
      s3_ruler_bucket  = "loki-ruler"
      s3_region        = "eu-central"
      s3_endpoint      = "https://YOUR_BUCKET_NAME.fsn1.your-objectstorage.com"
      s3_path_style    = true
      s3_access_key    = "YOUR_ACCESS_KEY"
      s3_secret_key    = "YOUR_SECRET_KEY"
    }
  }
}
```

---

### Use GCS for Loki storage (with Workload Identity)

Pre-create two GCS buckets before running `terraform apply`.

```hcl
module "loki" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/loki"

  loki = {
    namespace        = "monitoring"
    create_namespace = false
    retention_period = "744h"

    storage = {
      backend           = "gcs"
      gcs_chunks_bucket = "YOUR_PROJECT-loki-chunks"
      gcs_ruler_bucket  = "YOUR_PROJECT-loki-ruler"
      # gcs_service_account_key left empty — Workload Identity is used instead
    }

    service_account_annotations = {
      "iam.gke.io/gcp-service-account" = "loki@YOUR_GCP_PROJECT.iam.gserviceaccount.com"
    }
  }
}
```

---

### Add a custom Grafana dashboard from a JSON file

Place your dashboard JSON anywhere in the repo, then pass it via `extra_dashboards`. The key is the filename that appears in Grafana.

```hcl
module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id

    extra_dashboards = {
      "my-app.json"      = file("${path.module}/dashboards/my-app.json")
      "another-app.json" = file("${path.module}/dashboards/another-app.json")
    }
  }
}
```

---

### Add a custom Grafana dashboard by grafana.com ID

Find the dashboard on [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards), note its ID and revision number.

```hcl
module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id

    grafana_dashboard_imports = [
      # Node Exporter Full — already included by default, shown here as example
      { gnet_id = 1860, revision = 37, datasource = "Mimir" },
      # Kubernetes / Compute Resources / Cluster
      { gnet_id = 15520, revision = 9, datasource = "Mimir" },
      # Loki dashboard
      { gnet_id = 13639, revision = 2, datasource = "Loki" },
    ]
  }
}
```

---

### Add custom Prometheus alert rules from a YAML file

Write a standard PrometheusRule-compatible YAML file and pass it via `extra_rules`.

**`rules/my-app.yaml`:**

```yaml
groups:
  - name: my-app
    rules:
      - alert: MyAppHighErrorRate
        expr: rate(http_requests_total{job="my-app",status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on my-app"
          description: "Error rate is {{ $value | humanizePercentage }} over the last 5 minutes."
```

```hcl
module "prometheus_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus-rules"

  prometheus_rules = {
    namespace             = "monitoring"
    prometheus_release_id = module.prometheus.helm_release_id

    extra_rules = {
      "my-app.yaml" = file("${path.module}/rules/my-app.yaml")
    }
  }
}
```

---

### Enable Slack alerts (prometheus-rules)

Alerts at `warning` severity or above are forwarded to Slack. Critical alerts also go to Slack unless you raise `min_severity`.

```hcl
module "prometheus_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus-rules"

  prometheus_rules = {
    namespace             = "monitoring"
    prometheus_release_id = module.prometheus.helm_release_id

    slack = {
      enabled      = true
      webhook_url  = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
      channel      = "#platform-alerts"
      min_severity = "warning"
    }
  }
}
```

---

### Enable PagerDuty alerts (grafana-rules)

Only `critical` alerts page by default. Lower `min_severity` to `warning` to increase coverage.

```hcl
module "grafana_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/grafana-rules"

  grafana_rules = {
    namespace = "monitoring"

    pagerduty = {
      enabled         = true
      integration_key = "YOUR_PAGERDUTY_INTEGRATION_KEY"
      min_severity    = "critical"
    }
  }
}
```

---

### Enable ingress for Grafana with TLS via cert-manager

This requires the cert-manager module to be deployed first. The `cluster_issuer_name` in cert-manager must match the `cert-manager.io/cluster-issuer` annotation below.

```hcl
module "cert_manager" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/cert-manager"

  cert_manager = {
    cluster_issuer_name = "selfsigned-cluster-issuer"
  }
}

module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id

    grafana_ingress = {
      enabled    = true
      host       = "grafana.YOUR_DOMAIN"
      class_name = "nginx"
      tls_secret = "grafana-tls"
      annotations = {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      }
    }

    prometheus_ingress = {
      enabled    = true
      host       = "prometheus.YOUR_DOMAIN"
      class_name = "nginx"
      tls_secret = "prometheus-tls"
      annotations = {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      }
    }

    alertmanager_ingress = {
      enabled    = true
      host       = "alertmanager.YOUR_DOMAIN"
      class_name = "nginx"
      tls_secret = "alertmanager-tls"
      annotations = {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      }
    }
  }
}
```

---

## Storage Backends

All modules default to local disk storage. For production, use an object storage backend. Buckets and containers must be created before running `terraform apply` — these modules do not create them.

| Module | local | S3 | GCS | Azure |
| --- | :---: | :---: | :---: | :---: |
| mimir | yes | yes | yes | yes |
| loki | yes | yes | yes | yes |
| tempo | yes | yes | yes | yes |
| otel-collector | n/a | n/a | n/a | n/a |
| prometheus | n/a | n/a | n/a | n/a |
| cert-manager | n/a | n/a | n/a | n/a |

**S3 bucket requirements per module:**

| Module | Required buckets |
| --- | --- |
| mimir | `s3_blocks_bucket`, `s3_ruler_bucket`, `s3_alertmanager_bucket` |
| loki | `s3_chunks_bucket`, `s3_ruler_bucket` |
| tempo | `s3_bucket` |

**GCS bucket requirements per module:**

| Module | Required buckets |
| --- | --- |
| mimir | `gcs_blocks_bucket`, `gcs_ruler_bucket`, `gcs_alertmanager_bucket` |
| loki | `gcs_chunks_bucket`, `gcs_ruler_bucket` |
| tempo | `gcs_bucket` |

**Azure container requirements per module:**

| Module | Required containers |
| --- | --- |
| mimir | `azure_storage_account`, `azure_blocks_container`, `azure_ruler_container`, `azure_alertmanager_container` |
| loki | `azure_storage_account`, `azure_chunks_container`, `azure_ruler_container` |
| tempo | `azure_storage_account`, `azure_container` |

For IRSA (AWS) or Workload Identity (GCP/Azure), leave the key fields empty and provide the IAM annotation via `service_account_annotations`. The module does not create IAM roles — pre-create the role and supply the annotation.

```hcl
# IRSA (EKS)
service_account_annotations = {
  "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/mimir"
}

# GKE Workload Identity
service_account_annotations = {
  "iam.gke.io/gcp-service-account" = "mimir@YOUR_GCP_PROJECT.iam.gserviceaccount.com"
}
```

---

## Architecture

```
                          ┌─────────────────────────────────────────┐
                          │            Kubernetes Cluster            │
                          │                                          │
  ┌──────────┐  OTLP      │  ┌─────────────────────────────────┐   │
  │   Your   │──gRPC/HTTP─┼─▶│      OpenTelemetry Collector     │   │
  │   Apps   │            │  └──────┬──────────┬───────────┬───┘   │
  └──────────┘            │         │          │           │        │
                          │   traces│    metrics│      logs│        │
                          │         ▼          ▼           ▼        │
                          │  ┌──────────┐ ┌───────┐ ┌──────────┐  │
                          │  │  Tempo   │ │ Mimir │ │   Loki   │  │
                          │  │ (traces) │ │(metrics)│ │  (logs)  │  │
                          │  └────┬─────┘ └───┬───┘ └────┬─────┘  │
                          │       │            │          │         │
                          │       └────────────┼──────────┘         │
                          │                    │ query               │
                          │                    ▼                     │
                          │           ┌─────────────────┐           │
                          │           │     Grafana      │           │
                          │           │  (dashboards +   │           │
                          │           │     alerts)      │           │
                          │           └────────┬─────────┘           │
                          └────────────────────┼─────────────────────┘
                                               │ HTTPS
                                               ▼
                                        Browser / User

  ┌──────────────────────────────────────────────────────┐
  │                    Alert routing                      │
  │                                                       │
  │  Prometheus ──▶ Alertmanager ──▶ Slack / PagerDuty  │
  │  Grafana rules ────────────────▶ Slack / PagerDuty  │
  └──────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────┐
  │                   Prometheus scraping                 │
  │                                                       │
  │  Kubernetes nodes, pods, services                     │
  │         │                                             │
  │         ▼                                             │
  │    Prometheus ──remote_write──▶ Mimir                 │
  └──────────────────────────────────────────────────────┘
```

**Component roles at a glance:**

| Component | Role |
| --- | --- |
| Mimir | Long-term metrics storage and query backend |
| Loki | Log aggregation and query |
| Tempo | Distributed trace storage and query |
| Prometheus | Cluster scraping and remote write to Mimir |
| Grafana | Unified dashboards and alert management |
| OTel Collector | OTLP receiver — forwards traces to Tempo, metrics to Mimir, logs to Loki |
| cert-manager | TLS certificate issuance for ingress |
| prometheus-rules | Prometheus alert rules and Alertmanager receivers |
| grafana-rules | Grafana-managed alert rules and contact points |
