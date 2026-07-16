<div align="center">

<a href="https://digitalis.io/">
  <img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="400"/>
</a>

# terraform-k8s-monitoring

**Terraform modules for deploying a full observability stack on Kubernetes — by [Digitalis.io](https://digitalis.io)**

</div>

Metrics (Mimir), logs (Loki), traces (Tempo), collection (OpenTelemetry Collector), dashboards and alerts (Grafana via kube-prometheus-stack). Works on any Kubernetes cluster — EKS, GKE, AKS, or bare metal. Metrics (Mimir), logs (Loki), traces (Tempo), collection (OpenTelemetry Collector), dashboards and alerts (Grafana via kube-prometheus-stack). Works on any Kubernetes cluster — EKS, GKE, AKS, or bare metal.

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
  - [alloy](#alloy)
  - [pyroscope](#pyroscope)
  - [prometheus-rules](#prometheus-rules)
  - [grafana-rules](#grafana-rules)
- [Common Recipes](#common-recipes)
- [Storage Backends](#storage-backends)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

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
    chart_version       = "v1.21.0"
    namespace           = "cert-manager"
    create_namespace    = true
    cluster_issuer_name = "selfsigned-cluster-issuer"
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"v1.21.0"` | cert-manager Helm chart version |
| `namespace` | `"cert-manager"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `cluster_issuer_name` | `"selfsigned-cluster-issuer"` | Name of the ClusterIssuer to create — must match the `cert-manager.io/cluster-issuer` annotation in other modules |
| `node_selector` | `{}` | `nodeSelector` applied to all cert-manager components (controller, webhook, cainjector, startupapicheck) |
| `tolerations` | `[]` | Tolerations applied to all cert-manager components, letting the pods schedule onto tainted pools (e.g. GKE's `kubernetes.io/arch=arm64:NoSchedule`). Object list: `key`, `operator` (default `"Equal"`), `value`, `effect`. For `Exists`-style tolerations set `operator = "Exists"` and leave `value` empty |
| `kubeconfig_path` | `""` | Path to the kubeconfig file used by the `kubectl` local-exec provisioner. When empty, `--kubeconfig` is omitted and kubectl uses its standard resolution order (`KUBECONFIG` env var → `~/.kube/config`). Set explicitly to pin to a specific file (see [Troubleshooting](#troubleshooting)) |

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
| `chart_version` | `"6.1.0"` | Mimir distributed Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `retention_period` | `"30d"` | How long to keep metrics |
| `tenant_id` | `"anonymous"` | Value sent in `X-Scope-OrgID` header by Prometheus and Grafana |
| `replicas` | `1` | Number of replicas for each Mimir component |
| `ingress_enabled` | `false` | Expose Mimir via an Ingress |
| `ingress_host` | `""` | Hostname for the Mimir ingress (required when `ingress_enabled = true`) |
| `ingress_class_name` | `"nginx"` | Ingress class |
| `ingress_tls_secret` | `""` | TLS secret name |
| `storage.backend` | `"local"` | Storage backend: `local`, `s3`, `gcs`, or `azure` |
| `storage.s3_blocks_prefix` | `""` | Object key prefix for blocks — allows sharing one S3 bucket across all three Mimir storage types |
| `storage.s3_ruler_prefix` | `""` | Object key prefix for ruler data |
| `storage.s3_alertmanager_prefix` | `""` | Object key prefix for Alertmanager data |
| `storage.s3_credentials_secret` | `null` | Reference a pre-existing Kubernetes Secret for S3 credentials (see [S3 credentials secret](#s3-credentials-secret)) |
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
| `chart_version` | `"87.16.1"` | kube-prometheus-stack Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `namespace_labels` | `{}` | Additional labels to apply to the namespace |
| `namespace_annotations` | `{}` | Additional annotations to apply to the namespace |
| `grafana_enabled` | `true` | Deploy Grafana |
| `alertmanager_enabled` | `true` | Deploy Alertmanager |
| `grafana_replicas` | `1` | Number of Grafana replicas. Values > 1 require `grafana_database` (SQLite cannot be shared across pods) |
| `prometheus_enabled` | `true` | Deploy the Prometheus server. Set `false` (with the other component toggles) for a Grafana-only install |
| `prometheus_operator_enabled` | `true` | Deploy the Prometheus Operator. CRDs are installed regardless of this toggle |
| `kube_state_metrics_enabled` | `true` | Deploy kube-state-metrics |
| `node_exporter_enabled` | `true` | Deploy Prometheus node-exporter |
| `default_rules_enabled` | `true` | Create the bundled default alerting/recording `PrometheusRule` resources |
| `grafana_database` | `null` | External DB backend for Grafana — moves state off the ephemeral SQLite (required for `grafana_replicas > 1`). Object; see the [Grafana external database](#grafana-external-database) table below. `null` keeps the chart's built-in SQLite |
| `mimir_remote_write_url` | `""` | Mimir remote_write URL — use `module.mimir.remote_write_endpoint` |
| `mimir_datasource_url` | `""` | Mimir query URL — use `module.mimir.query_frontend_endpoint` |
| `mimir_tenant_id` | `"anonymous"` | Tenant ID for `X-Scope-OrgID` header |
| `loki_datasource_url` | `""` | Loki URL — use `module.loki.datasource_url` |
| `tempo_datasource_url` | `""` | Tempo URL — use `module.tempo.datasource_url` |
| `loki_trace_id_field` | `"trace_id"` | Name of the trace-id field in the JSON log body. Builds a Grafana derived field (regex matcher `"<field>":"(\w+)"`) linking a log line to its trace in Tempo (active only when both `loki_datasource_url` and `tempo_datasource_url` are set). Set `""` to disable the link |
| `pyroscope_datasource_url` | `""` | Pyroscope URL — use `module.pyroscope.datasource_url` |
| `tempo_profile_type_id` | `"process_cpu:cpu:nanoseconds:cpu:nanoseconds"` | Default Pyroscope profile type for the Tempo **Trace to profiles** link (span → Pyroscope). Active only when both `tempo_datasource_url` and `pyroscope_datasource_url` are set. Set `""` to disable |
| `clickhouse_datasource` | `null` | ClickHouse datasource config — see [ClickHouse integration](#clickhouse-integration) |
| `storage_size` | `"20Gi"` | PVC size for Prometheus TSDB |
| `storage_class` | `""` | StorageClass name (cluster default if empty) |
| `retention` | `"24h"` | Local TSDB retention (metrics are in Mimir long-term) |
| `grafana_dashboard_imports` | Node Exporter Full (1860) | Grafana.com dashboard IDs to import |
| `extra_dashboards` | `{}` | Additional dashboard JSON — `{ "name.json" = file("...") }` |
| `grafana_plugins` | see below | Grafana plugins to install |
| `grafana_ingress` | disabled | Grafana ingress config (see [Enable ingress](#enable-ingress-for-grafana-with-tls-via-cert-manager)) |
| `prometheus_ingress` | disabled | Prometheus ingress config |
| `alertmanager_ingress` | disabled | Alertmanager ingress config |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 200m CPU / 512Mi memory request, 2 CPU / 2Gi memory limit.

Default Grafana plugins: `digrich-bubblechart-panel`, `grafana-clock-panel`, `btplc-status-dot-panel`, `grafana-piechart-panel`, `grafana-llm-app`, `grafana-clickhouse-datasource`.

#### Grafana external database

Fields of the `grafana_database` object. Supply the password with **exactly one** of `password` or `password_secret` (or neither for passwordless/IAM auth); it is injected as `GF_DATABASE_PASSWORD` via a `secretKeyRef` and never rendered into the Helm values.

| Field | Required | Default | Description |
| --- | --- | --- | --- |
| `type` | no | `"postgres"` | `"postgres"` or `"mysql"` |
| `host` | yes | — | `"host:port"`, e.g. `"pg.db.svc:5432"` |
| `name` | yes | — | Database name |
| `user` | yes | — | Database user |
| `password` | no | `""` | Plaintext password — the module creates a `prometheus-grafana-db` Secret. Mutually exclusive with `password_secret` |
| `password_secret` | no | `null` | Reference an existing Secret: `{ name = "grafana-db", field = "password" }` (`field` defaults to `"password"`) |
| `ssl_mode` | no | `""` | PostgreSQL only: `disable`/`require`/`verify-ca`/`verify-full`. Must be `""` for `mysql` |

```hcl
prometheus = {
  grafana_replicas = 2
  grafana_database = {
    type            = "postgres"
    host            = "pg.db.svc:5432"
    name            = "grafana"
    user            = "grafana"
    ssl_mode        = "require"
    password_secret = { name = "grafana-db", field = "password" }
  }
}
```

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
| `chart_version` | `"7.1.0"` | Loki Helm chart version |
| `chart_repository` | `"https://grafana.github.io/helm-charts"` | Helm repo for the Loki chart. Point at the `grafana-community` fork (with a community `chart_version`) to run Loki ≥ 3.7 |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `deployment_mode` | `"single-binary"` | `single-binary` or `scalable` |
| `replicas` | `1` | Replica count (single-binary mode) |
| `retention_period` | `"744h"` | Log retention period (31 days) |
| `storage.backend` | `"local"` | Storage backend: `local`, `s3`, `gcs`, or `azure` |
| `storage.s3_credentials_secret` | `null` | Reference a pre-existing Kubernetes Secret for S3 credentials (see [S3 credentials secret](#s3-credentials-secret)) |
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
| `chart_version` | `"1.61.3"` | Tempo Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `namespace_labels` | `{}` | Additional labels to apply to the namespace |
| `namespace_annotations` | `{}` | Additional annotations to apply to the namespace |
| `deployment_mode` | `"monolithic"` | `monolithic` or `distributed` |
| `replicas` | `1` | Replica count (monolithic mode) |
| `retention` | `"720h"` | Trace retention period (30 days) |
| `metrics_generator_remote_write_url` | `""` | Mimir (or Prometheus) remote_write URL to enable metrics-generator for TraceQL `rate()` and span metrics |
| `storage.backend` | `"local"` | Storage backend: `local`, `s3`, `gcs`, or `azure` |
| `storage.s3_key_prefix` | `""` | Object key prefix (example: `"tempo"`); optional, enables sharing one bucket with Mimir/Loki |
| `storage.s3_credentials_secret` | `null` | Reference a pre-existing Kubernetes Secret for S3 credentials (see [S3 credentials secret](#s3-credentials-secret)) |
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

Installs the OpenTelemetry Collector (contrib image). Receives OTLP traces, metrics, and logs from your applications and forwards them to Tempo, Mimir, and Loki respectively. Optionally enables the OpenTelemetry Operator for workload instrumentation. Runs as a DaemonSet by default.

```hcl
module "otel" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/otel-collector"

  otel = {
    namespace        = "monitoring"
    create_namespace = false
    mode             = "daemonset"
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    mimir_tenant_id  = module.mimir.tenant_id
    loki_endpoint    = module.loki.datasource_url
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"0.165.0"` | OpenTelemetry Collector Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `namespace_labels` | `{}` | Additional labels to apply to the namespace |
| `namespace_annotations` | `{}` | Additional annotations to apply to the namespace |
| `mode` | `"daemonset"` | `daemonset` or `deployment` |
| `release_name` | `"otel"` | Helm release name. Override to run two collectors in one namespace (e.g. a `deployment` gateway plus a `daemonset` agent) |
| `node_selector` | `{}` | `nodeSelector` pinning the collector (and operator) to matching nodes |
| `tolerations` | `[]` | Tolerations letting the collector — and, when enabled, the operator — schedule onto tainted pools (e.g. GKE's `kubernetes.io/arch=arm64:NoSchedule`). Object list: `key`, `operator` (default `"Equal"`), `value`, `effect`. For `Exists`-style tolerations set `operator = "Exists"` and leave `value` empty |
| `tempo_endpoint` | `""` | OTLP gRPC endpoint for Tempo — use `module.tempo.otlp_grpc_endpoint` |
| `mimir_endpoint` | `""` | Remote write URL for Mimir — use `module.mimir.remote_write_endpoint` |
| `mimir_tenant_id` | `"anonymous"` | Tenant ID for `X-Scope-OrgID` header sent to Mimir — use `module.mimir.tenant_id` |
| `loki_endpoint` | `""` | Loki push URL — use `module.loki.datasource_url` |
| `clickhouse_endpoint` | `""` | ClickHouse HTTP endpoint (`:8123`) for logs and traces |
| `clickhouse_username` | `""` | ClickHouse username |
| `clickhouse_password` | `""` | ClickHouse password |
| `clickhouse_database` | `"otel"` | ClickHouse database name for OTLP/ClickHouse exporter |
| `clickhouse_create_schema` | `true` | Auto-create database and tables on startup. Disable on memory-constrained ClickHouse instances and pre-create the schema manually |
| `clickhouse_cluster` | `""` | ClickHouse cluster name. Set to emit `ON CLUSTER` DDL so `otel_logs`/`otel_traces` are created on every node of a load-balanced cluster, not just the connected one |
| `clickhouse_table_engine` | `""` | Table engine for the ClickHouse exporter, e.g. `ReplicatedMergeTree`. Pair with `clickhouse_cluster` for a replicated cluster |
| `log_parsing.json_enabled` | `true` | Parse JSON pod-log bodies (daemonset mode). When `false`, the `filelog` receiver uses only the `container` operator and bodies stay opaque |
| `log_parsing.json_match_expr` | `body matches "^\\s*[{]"` | OTel `filelog` `if` guard — only bodies matching this expr are JSON-parsed, so plain-text logs pass through untouched. Override to match your log shape (e.g. `hasPrefix(body, "{")`) |
| `log_parsing.severity_field` | `"level"` | JSON field mapped to `SeverityText`/`SeverityNumber`. Set `""` to disable severity mapping |
| `log_parsing.trace_enabled` | `true` | Promote `trace_id`/`span_id` into the log record's trace context (fills ClickHouse `TraceId`/`SpanId`). Requires `json_enabled = true` |
| `log_parsing.trace_id_field` | `"trace_id"` | JSON field holding the trace id (e.g. `traceID`, `traceId`, `dd.trace_id`) |
| `log_parsing.span_id_field` | `"span_id"` | JSON field holding the span id (e.g. `spanID`, `spanId`) |
| `image.repository` | `"otel/opentelemetry-collector-contrib"` | Collector image (contrib required for Loki and Mimir exporters) |
| `image.tag` | `""` | Image tag (empty = chart appVersion) |
| `image.pull_policy` | `"IfNotPresent"` | Image pull policy |
| `operator.enabled` | `false` | Deploy the OpenTelemetry Operator for auto-instrumentation |
| `operator.chart_version` | `"0.120.0"` | Operator Helm chart version |
| `operator.collector_image_repository` | `"otel/opentelemetry-collector-k8s"` | Operator's default collector image repository |
| `operator.cert_manager_enabled` | `false` | Use cert-manager for webhook certificates |
| `operator.auto_generate_cert_enabled` | `true` | Auto-generate webhook certificates (incompatible with cert-manager) |
| `operator.extra_args` | `[]` | Additional arguments to pass to the operator |
| `operator.go_instrumentation_enabled` | `false` | Enable Go auto-instrumentation via eBPF (requires Linux kernel >=4.19) |
| `operator.go_instrumentation_image` | `""` | Go instrumentation image (defaults to chart appVersion when empty) |
| `service_account_annotations` | `{}` | Annotations for IRSA / Workload Identity |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 300m CPU / 256Mi memory request, 500m CPU / 512Mi memory limit.

**Outputs:**

| Output | Description |
| --- | --- |
| `otlp_grpc_endpoint` | OTLP gRPC endpoint your apps send traces to (port 4317) |
| `otlp_http_endpoint` | OTLP HTTP endpoint your apps send traces to (port 4318) |
| `namespace` | Namespace where the collector is deployed |
| `helm_release_name` | Helm release name |
| `helm_release_version` | Deployed chart version |

---

### alloy

Installs [Grafana Alloy](https://grafana.com/docs/alloy/) — the OpenTelemetry-native successor to Grafana Agent. Receives OTLP traces, metrics, logs, and profiles from instrumented applications using a River/Alloy pipeline config, and forwards each signal to the configured backend. Runs as a DaemonSet by default (one pod per node), but supports Deployment and StatefulSet controller types.

```hcl
module "alloy" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/alloy"

  alloy = {
    namespace        = "monitoring"
    create_namespace = false
    controller_type  = "daemonset"
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    mimir_tenant_id  = module.mimir.tenant_id
    loki_endpoint    = module.loki.datasource_url
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"1.10.1"` | Alloy Helm chart version — check [ArtifactHub](https://artifacthub.io/packages/helm/grafana/alloy) for the latest |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `namespace_labels` | `{}` | Additional labels to apply to the namespace |
| `namespace_annotations` | `{}` | Additional annotations to apply to the namespace |
| `release_name` | `"alloy"` | Helm release name — override to deploy a second Alloy-based release into the same namespace without colliding (e.g. a Faro receiver gateway alongside a daemonset collector — see below) |
| `controller_type` | `"daemonset"` | Kubernetes workload kind: `daemonset`, `deployment`, or `statefulset` |
| `replicas` | `1` | Replica count (ignored when `controller_type = "daemonset"`) |
| `alloy_config` | `""` | Full River/Alloy pipeline config. When empty, a built-in default config is rendered — either the OTLP receiver below, or the Faro receiver when `faro_receiver.enabled = true` |
| `faro_receiver.enabled` | `false` | Opt-in [Grafana Faro](https://grafana.com/oss/faro/) real-user-monitoring (RUM) receiver. Grafana does not publish a standalone "faro" Helm chart — enabling this swaps the built-in config to Alloy's `faro.receiver` component instead of the OTLP receiver. Faro has no metrics output, so `mimir_endpoint` is not used when enabled. Pair with `controller_type = "deployment"` and a distinct `release_name` to run it alongside a separate daemonset collector |
| `faro_receiver.port` | `12347` | HTTP port the Faro receiver listens on for browser SDK payloads (only used when `faro_receiver.enabled = true`) |
| `extra_ports` | OTLP gRPC/HTTP (4317/4318), or Faro's `port` when `faro_receiver.enabled = true` | List of `{ name, port, target_port, protocol }` objects exposed on the Alloy pod/Service. Override when `alloy_config` wires a component that listens on its own port |
| `loki_endpoint` | `""` | Loki push URL — use `module.loki.datasource_url` |
| `tempo_endpoint` | `""` | Tempo OTLP gRPC endpoint — use `module.tempo.otlp_grpc_endpoint` |
| `mimir_endpoint` | `""` | Mimir remote write URL — use `module.mimir.remote_write_endpoint` |
| `mimir_tenant_id` | `"anonymous"` | Value sent in `X-Scope-OrgID` header to Mimir — use `module.mimir.tenant_id` |
| `pyroscope_endpoint` | `""` | Pyroscope push URL — use `module.pyroscope.push_url` |
| `otel_grpc_endpoint` | `""` | Upstream OTel Collector endpoint for chaining — use `module.otel.otlp_grpc_endpoint` |
| `persistence.enabled` | `false` | Mount a PVC for WAL state (only meaningful with `controller_type = "statefulset"`) |
| `persistence.size` | `"10Gi"` | PVC size |
| `persistence.storage_class` | `""` | StorageClass name (cluster default if empty) |
| `ingress.enabled` | `false` | Expose the Faro receiver via an Ingress. Requires `faro_receiver.enabled = true` — the chart's ingress feature always targets a fixed Faro port, regardless of any other component |
| `ingress.host` | `""` | Ingress hostname (required when `ingress.enabled = true`) |
| `ingress.class_name` | `"nginx"` | Ingress class |
| `ingress.tls_secret` | `""` | TLS secret name |
| `service_account_annotations` | `{}` | Annotations for IRSA / Workload Identity |
| `resources` | see below | CPU/memory requests and limits |
| `extra_values` | `""` | Extra Helm values merged last (highest precedence) |
| `sensitive_data.enabled` | `true` | Hash or delete matched sensitive attributes on logs, traces, and metrics before export |
| `sensitive_data.action` | `"hash"` | Default action for matched fields: `"hash"` (SHA256, optionally salted) or `"delete"` |
| `sensitive_data.default_rules_enabled` | `true` | Include the built-in financial-institution field list (below) |
| `sensitive_data.custom_rules` | `{}` | Extra `{ "attribute.name" = "hash" \| "delete" }` entries; overrides the default action for shared field names |
| `sensitive_data.salt` | `""` | Mixed into the hash input so output is deterministic but not a plain unsalted hash |

Default resources: 100m CPU / 128Mi memory request, 500m CPU / 512Mi memory limit.

**Sensitive-data (PII) processor**

Enabled by default. Wires an `otelcol.processor.transform` component into the built-in pipeline (receiver → transform → batch → exporters) that matches known attribute names on log records, spans, and metric datapoints and either hashes (SHA256) or deletes them, per [OpenTelemetry's guidance on handling sensitive data](https://opentelemetry.io/docs/security/handling-sensitive-data/). It matches on attribute keys, not free-text log bodies. `error_mode = "propagate"` is set deliberately — a malformed rule fails the pipeline loudly rather than silently letting unredacted data through.

Default field list is split into two groups (financial-institution oriented):
- **Secrets/credentials** — always `delete`, regardless of `action`: `password`, `passwd`, `pwd`, `secret`, `api_key`, `apikey`, `token`, `authorization`. A hash of a credential is still a stable, attackable fingerprint of it, so these are never hashed by default.
- **PII** — subject to the configurable `action`: `card_number`, `credit_card_number`, `credit_card`, `pan`, `cvv`, `cvv2`, `card_cvv`, `ssn`, `social_security_number`, `iban`, `bank_account_number`, `account_number`, `email`, `email_address`.

`custom_rules` overrides either group's action per field name.

**Salt is not a secret.** It is rendered in plaintext into the Alloy ConfigMap (and into Terraform state via the `helm_release` values). It deters trivial rainbow-table reuse of the *same* precomputed table across deployments/fields, but anyone with read access to the ConfigMap or state can recompute hashes for known candidate values (e.g. brute-forcing a 16-digit PAN is infeasible, but a known SSN or email is not). Do not rely on it as a cryptographic secret.

Only applies to the built-in config — a non-empty `alloy_config` takes full control of the pipeline and must wire its own transform processor if needed.

```hcl
# Defaults only (hash all default fields, no salt)
alloy = {
  sensitive_data = {}
}

# Custom action + salt + extra/overridden fields
alloy = {
  sensitive_data = {
    action = "hash"
    salt   = "my-org-salt"
    custom_rules = {
      "user.ssn"       = "delete" # overrides the default "hash" action
      "transaction.id" = "hash"   # field not covered by the defaults
    }
  }
}

# Disable entirely
alloy = {
  sensitive_data = { enabled = false }
}
```

**Outputs:**

| Output | Description |
| --- | --- |
| `otlp_grpc_endpoint` | OTLP gRPC endpoint for app instrumentation — `http://alloy.<namespace>.svc.cluster.local:4317` |
| `otlp_http_endpoint` | OTLP HTTP endpoint for app instrumentation — `http://alloy.<namespace>.svc.cluster.local:4318` |
| `namespace` | Namespace where Alloy is deployed |
| `helm_release_name` | Helm release name |
| `helm_release_version` | Deployed chart version |
| `helm_release_id` | Helm release ID — dependency anchor for other modules |
| `faro_receiver_http_endpoint` | In-cluster HTTP endpoint for the Faro Web SDK `baseUrl` — set only when `faro_receiver.enabled = true`, empty string otherwise |
| `faro_receiver_public_url` | Public HTTPS/HTTP URL — set only when `faro_receiver.enabled = true` and `ingress.enabled = true`, empty string otherwise |

**Faro receiver example** — a Deployment-mode gateway accepting browser RUM telemetry, deployed alongside a separate daemonset collector in the same namespace:

```hcl
module "alloy" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/alloy"
  alloy = {
    namespace        = "monitoring"
    controller_type  = "daemonset"
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    loki_endpoint    = module.loki.datasource_url
  }
}

module "faro_receiver" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/alloy"
  alloy = {
    release_name      = "faro-receiver"
    namespace         = "monitoring"
    create_namespace  = false
    controller_type   = "deployment"
    replicas          = 2
    faro_receiver     = { enabled = true }
    tempo_endpoint    = module.tempo.otlp_grpc_endpoint
    loki_endpoint     = module.loki.datasource_url
    ingress = {
      enabled    = true
      host       = "faro.example.com"
      tls_secret = "faro-tls"
    }
  }
}
```

---

### pyroscope

Installs Grafana Pyroscope for continuous profiling. Collects CPU, memory, goroutine, and heap profiles from Go, Java, Python, Ruby, and other supported runtimes. Profiles are stored in Pyroscope and queried through a dedicated Grafana datasource.

```hcl
module "pyroscope" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/pyroscope"

  pyroscope = {
    namespace        = "monitoring"
    create_namespace = false
  }
}
```

| Variable | Default | Description |
| --- | --- | --- |
| `chart_version` | `"2.1.1"` | Pyroscope Helm chart version |
| `namespace` | `"monitoring"` | Namespace to deploy into |
| `create_namespace` | `true` | Create the namespace if it does not exist |
| `namespace_labels` | `{}` | Additional labels to apply to the namespace |
| `namespace_annotations` | `{}` | Additional annotations to apply to the namespace |
| `replicas` | `1` | Number of Pyroscope replicas |
| `storage.backend` | `"local"` | Storage backend: `local`, `s3`, `gcs`, or `azure` |
| `storage.s3_bucket` | `""` | S3 bucket name |
| `storage.s3_region` | `""` | S3 region |
| `storage.s3_endpoint` | `""` | S3-compatible endpoint hostname (scheme stripped automatically) |
| `storage.s3_insecure` | `false` | Use plain HTTP for the S3 endpoint |
| `storage.s3_access_key` | `""` | S3 access key (leave empty for IRSA) |
| `storage.s3_secret_key` | `""` | S3 secret key (leave empty for IRSA) |
| `storage.s3_key_prefix` | `""` | Object key prefix (example: `"pyroscope"`); optional, enables sharing one bucket with other components |
| `storage.s3_credentials_secret` | `null` | Reference a pre-existing Kubernetes Secret for S3 credentials (see [S3 credentials secret](#s3-credentials-secret)) |
| `storage.gcs_bucket` | `""` | GCS bucket name |
| `storage.gcs_service_account_key` | `""` | GCS service account JSON key (leave empty for Workload Identity) |
| `storage.azure_storage_account` | `""` | Azure storage account name |
| `storage.azure_container` | `""` | Azure blob container name |
| `storage.azure_storage_account_key` | `""` | Azure storage account key |
| `service_account_annotations` | `{}` | Annotations for IRSA / Workload Identity |
| `resources` | see below | CPU/memory requests and limits |

Default resources: 100m CPU / 256Mi memory request, 1 CPU / 1Gi memory limit.

> **S3 path-style not supported.** Pyroscope's S3 client does not support `bucket_lookup_type` (path-style access). When using an S3-compatible service such as Hetzner Object Storage, Exoscale, or Cloudflare R2, use a bucket-specific endpoint instead of a shared endpoint with `s3_path_style = true`:
>
> ```hcl
> storage = {
>   backend      = "s3"
>   s3_bucket    = "mybucket"
>   s3_region    = "ch-gva-2"
>   s3_endpoint  = "mybucket.sos-ch-gva-2.exo.io"  # bucket-specific endpoint
>   s3_access_key = "YOUR_ACCESS_KEY"
>   s3_secret_key = "YOUR_SECRET_KEY"
> }
> ```

**Outputs:**

| Output | Description |
| --- | --- |
| `datasource_url` | Pyroscope URL for Grafana datasource — wire into the prometheus module as `pyroscope_datasource_url` |
| `push_url` | Pyroscope push URL for profiling agents — `http://pyroscope.<namespace>.svc.cluster.local:4040` |
| `namespace` | Namespace where Pyroscope is deployed |
| `helm_release_name` | Helm release name |
| `helm_release_version` | Deployed chart version |

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
| `kubeconfig_path` | `""` | Path to the kubeconfig file used by `kubectl` local-exec. When empty, `--kubeconfig` is omitted and kubectl uses its standard resolution order (`KUBECONFIG` env var → `~/.kube/config`). Set explicitly to pin to a specific file (see [Troubleshooting](#troubleshooting)) |
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

Complete, copy-paste examples are available in the `examples/` directory:

| Example | Description |
| --- | --- |
| `examples/minimal/` | Full stack with local disk storage — no cloud credentials needed |
| `examples/alloy-basic/` | Alloy DaemonSet collector wired to Loki, Tempo, and Mimir |
| `examples/alloy-faro-receiver/` | Alloy DaemonSet collector plus a second Alloy release configured as a Faro RUM receiver, both wired to Loki and Tempo |
| `examples/aws/` | S3 backend with IRSA authentication on EKS |
| `examples/s3compatible/` | S3-compatible storage (Hetzner, MinIO, Ceph) with path-style addressing |
| `examples/gcp/` | Full stack on GCS backend with Workload Identity on GKE |
| `examples/gcp/mimir-gcs/` | Metrics-only slice — Mimir (GCS) + Grafana on GKE, with ACME/Let's Encrypt ingress TLS |

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

Any S3-compatible service works. Set `s3_endpoint` to the service hostname or URL, `s3_path_style = true` (required by Hetzner and most non-AWS services), and provide access credentials.

The module strips `https://` and `http://` from `s3_endpoint` automatically, so both `"https://fsn1.your-objectstorage.com"` and `"fsn1.your-objectstorage.com"` are accepted.

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
      s3_endpoint            = "fsn1.your-objectstorage.com"  # Hetzner example — scheme optional
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
      s3_endpoint      = "fsn1.your-objectstorage.com"  # scheme optional
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

### Enable continuous profiling (Pyroscope)

Deploy Pyroscope and wire it into Grafana as a datasource. The `pyroscope_datasource_url` variable adds a `grafana-pyroscope-datasource` datasource with uid `pyroscope` to Grafana automatically.

```hcl
module "pyroscope" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/pyroscope"

  pyroscope = {
    namespace        = "monitoring"
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
    pyroscope_datasource_url = module.pyroscope.datasource_url
  }
}
```

Once deployed, push profiles from your applications to `http://pyroscope.monitoring.svc.cluster.local:4040`. Pyroscope uses port 4040 for both push ingestion and query.

---

### Enable Tempo metrics generator with Mimir backend

Tempo's metrics-generator extracts RED metrics (Request, Error, Duration) and custom span metrics from traces, then writes them to Mimir for long-term storage. This enables TraceQL `rate()` queries and correlation between traces and metrics.

```hcl
module "tempo" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/tempo"

  tempo = {
    namespace        = "monitoring"
    create_namespace = false
    # Enable metrics generation — write to the same Mimir endpoint as Prometheus
    metrics_generator_remote_write_url = module.mimir.remote_write_endpoint
  }
}

module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace         = false
    mimir_remote_write_url   = module.mimir.remote_write_endpoint
    mimir_datasource_url     = module.mimir.query_frontend_endpoint
    mimir_tenant_id          = module.mimir.tenant_id
    tempo_datasource_url     = module.tempo.datasource_url
  }
}
```

---

### ClickHouse integration for logs and traces

Use ClickHouse as an alternative backend for OTLP logs and traces. The OTel Collector exports directly to ClickHouse, and Grafana queries via the ClickHouse datasource plugin.

**Deploy ClickHouse first** (or use a managed instance), then wire the OTel Collector and Grafana datasource:

```hcl
module "otel" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/otel-collector"

  otel = {
    namespace           = "monitoring"
    create_namespace    = false
    tempo_endpoint      = module.tempo.otlp_grpc_endpoint
    mimir_endpoint      = module.mimir.remote_write_endpoint
    loki_endpoint       = module.loki.datasource_url
    # ClickHouse exporter configuration
    clickhouse_endpoint  = "clickhouse.observability.svc.cluster.local:8123"
    clickhouse_username  = "default"
    clickhouse_password  = "your-password"
    clickhouse_database  = "otel"
    clickhouse_create_schema = true  # auto-create tables on startup
  }
}

module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id

    # ClickHouse datasource for querying OTel logs/traces
    clickhouse_datasource = {
      host     = "clickhouse.observability.svc.cluster.local"
      port     = 9000
      database = "otel"
      username = "default"
      password = "your-password"
      secure   = false
      # OTel schema — matches tables created by the otel-collector ClickHouse exporter
      logs_otel_enabled    = true
      logs_default_table   = "otel_logs"
      traces_otel_enabled  = true
      traces_default_table = "otel_traces"
    }
  }
}
```

**Log ↔ trace correlation.** In `daemonset` mode the `filelog` receiver parses
structured JSON pod logs and promotes their trace context to native OTel fields:

- JSON log bodies matching the configured pattern (default: lines where body starts
  with `{` after trimming leading whitespace) are parsed into log attributes;
  plain-text logs pass through untouched.
- `SeverityText` and `SeverityNumber` are extracted from a JSON field (default:
  `level`; disable by setting `severity_field = ""`).
- `trace_id`/`span_id` attributes are promoted into the log record's trace
  context, so the ClickHouse `otel_logs.TraceId`/`SpanId` columns are populated
  and correlate directly with `otel_traces` — no `JSONExtractString(Body, …)`
  needed. This also drives Grafana logs↔traces linking.

To benefit, applications must log JSON to stdout with `trace_id` and `span_id`
fields (e.g. Go `slog` with a trace-enriching handler).

**Match your log field names.** The parser is fully configurable via
`log_parsing` — point it at whatever field names your loggers emit, change the
JSON detection guard, or disable parsing entirely:

```hcl
module "otel" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/otel-collector"

  otel = {
    namespace           = "monitoring"
    clickhouse_endpoint = "clickhouse.observability.svc.cluster.local:8123"

    log_parsing = {
      json_enabled    = true
      severity_field  = "level"       # empty "" disables severity mapping
      trace_id_field  = "trace_id"    # e.g. "traceID", "dd.trace_id"
      span_id_field   = "span_id"     # e.g. "spanID", "spanId"
      # Advanced: override the JSON-detection guard (expr-lang expression).
      # Match only logs starting with { without leading whitespace:
      # json_match_expr = "hasPrefix(body, \"{\")"
    }
  }
}
```

To turn parsing off (opaque bodies, no severity/trace promotion) set
`log_parsing = { json_enabled = false }`.

#### Grafana ClickHouse trace query (error-logs → traces)

Once `otel_logs.TraceId`/`SeverityText` are populated, this query drives a
Grafana **Table/Traces** panel showing traces that produced error logs. Adjust
the `tags` map keys to the span attributes **your** instrumentation emits — the
example below uses stable OpenTelemetry HTTP semantic conventions (≥ 1.21) and
derives the `error` tag from the span status, not a `SpanAttributes['error']`
key (which OTel does not set):

```sql
SELECT
    TraceId       AS traceID,
    SpanId        AS spanID,
    ParentSpanId  AS parentSpanID,
    SpanName      AS operationName,
    ServiceName   AS serviceName,
    Timestamp     AS startTime,
    multiply(Duration, 0.000001) AS duration,   -- ns -> ms

    cast(
        map(
            -- Stable HTTP semconv (>= 1.21). For older SDKs use
            -- http.method / http.status_code / http.target instead.
            'http.method',      SpanAttributes['http.request.method'],
            'http.status_code', SpanAttributes['http.response.status_code'],
            'http.route',       SpanAttributes['http.route'],
            'url.path',         SpanAttributes['url.path'],
            -- OTel marks span errors via status, not an attribute:
            'error',            if(StatusCode = 'Error', 'true', ''),
            'status.message',   StatusMessage
        ),
        'Map(String, String)'
    ) AS tags

FROM "otel"."otel_traces"
WHERE
    Timestamp >= $__fromTime AND Timestamp <= $__toTime
    AND Duration > 0
    AND TraceId IN (
        SELECT TraceId
        FROM "otel"."otel_logs"
        WHERE
            Timestamp >= $__fromTime AND Timestamp <= $__toTime
            AND (SeverityText = 'ERROR' OR SeverityNumber >= 17)
            AND TraceId != ''
    )
ORDER BY Timestamp DESC, Duration DESC
LIMIT 1000
```

> **Confirm your attribute keys** before trusting the `tags` map. Run
> `SELECT SpanAttributes FROM otel.otel_traces LIMIT 1 FORMAT Vertical` to inspect
> the actual span attribute keys your instrumentation emits, then update the query's
> `map()` keys accordingly. Only **new** logs and traces emitted after the collector
> is deployed carry populated `TraceId`/`SpanId` fields; historic rows are not backfilled.

---

### Log ↔ trace correlation with Loki + Tempo

When logs go to **Loki** and traces to **Tempo** (instead of, or alongside,
ClickHouse), correlation is wired in Grafana at the **datasource** level — there
is no shared table to join. The `prometheus` module configures both directions
automatically when the respective datasource URLs are set:

- **Trace → logs** (span → Loki): the Tempo datasource gets a `tracesToLogsV2`
  block (`filterByTraceID: true`), so opening a span jumps to its logs in Loki.
- **Log → trace** (Loki → Tempo): the Loki datasource gets a `derivedFields`
  entry that extracts the trace id from each log line and turns it into a
  **View trace** link to Tempo.

The derived field uses a **regex matcher** against the JSON log body
(`"<field>":"(\w+)"`, from `loki_trace_id_field`), not a structured-metadata
label matcher. A label matcher does not resolve a value in the Grafana Logs
Drilldown app, which leaves the Tempo query empty — so the regex form is used
for version-independent, reliable linking. This works because the OTel
Collector's `filelog` parsing (see [otel-collector](#otel-collector)
`log_parsing`) emits the `trace_id` field into the JSON log body.

```hcl
module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace     = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    loki_datasource_url    = module.loki.datasource_url
    tempo_datasource_url   = module.tempo.datasource_url

    # Name of the trace-id field in the JSON log body. Default "trace_id"
    # matches the otel-collector filelog output. Set "" to disable the link.
    loki_trace_id_field = "trace_id"
  }
}
```

> Both directions require both `loki_datasource_url` and `tempo_datasource_url`
> to be set. If your logs carry the trace id under a different JSON field name
> (e.g. `traceid`, `traceID`), point `loki_trace_id_field` at it.

---

### Trace ↔ profiles with Tempo + Pyroscope

When traces go to **Tempo** and continuous profiles to **Pyroscope**, the
`prometheus` module wires the Tempo datasource's **Trace to profiles**
(`tracesToProfiles`) link automatically — opening a span jumps to the matching
CPU profile in Pyroscope, correlated by `service.name`.

Active only when both `tempo_datasource_url` and `pyroscope_datasource_url` are
set. The `tempo_profile_type_id` variable selects which profile type opens by
default:

```hcl
module "prometheus" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus"

  prometheus = {
    create_namespace         = false
    mimir_remote_write_url   = module.mimir.remote_write_endpoint
    mimir_datasource_url     = module.mimir.query_frontend_endpoint
    tempo_datasource_url     = module.tempo.datasource_url
    pyroscope_datasource_url = module.pyroscope.datasource_url

    # Profile type opened from a span. Default is CPU time; set "" to disable.
    tempo_profile_type_id = "process_cpu:cpu:nanoseconds:cpu:nanoseconds"
  }
}
```

> The span → profile match uses the `service.name` span tag mapped to the
> Pyroscope `service_name` label, so your traces and profiles must share the
> same service name.

---

### Enable OpenTelemetry Operator for auto-instrumentation

The OpenTelemetry Operator enables zero-code instrumentation of workloads via annotations. Deployed workloads are automatically patched with OTEL_JAVAAGENT, Go eBPF instrumentation, or Python auto-instrumentation.

```hcl
module "otel" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/otel-collector"

  otel = {
    namespace        = "monitoring"
    create_namespace = false

    operator = {
      enabled           = true
      chart_version     = "0.120.0"
      cert_manager_enabled = false  # auto-generate webhook certs by default
      # Enable Go eBPF instrumentation (requires Linux kernel >=4.19)
      go_instrumentation_enabled = true
    }
  }
}
```

After deployment, annotate your workload to enable instrumentation:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-java: "true"  # or inject-python, inject-go
    spec:
      containers:
      - name: app
        image: my-app:latest
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
| pyroscope | yes | yes | yes | yes |
| otel-collector | n/a | n/a | n/a | n/a |
| prometheus | n/a | n/a | n/a | n/a |
| cert-manager | n/a | n/a | n/a | n/a |

**S3 bucket requirements per module:**

| Module | Required buckets |
| --- | --- |
| mimir | `s3_blocks_bucket`, `s3_ruler_bucket`, `s3_alertmanager_bucket` |
| loki | `s3_chunks_bucket`, `s3_ruler_bucket` |
| tempo | `s3_bucket` |
| pyroscope | `s3_bucket` |

**GCS bucket requirements per module:**

| Module | Required buckets |
| --- | --- |
| mimir | `gcs_blocks_bucket`, `gcs_ruler_bucket`, `gcs_alertmanager_bucket` |
| loki | `gcs_chunks_bucket`, `gcs_ruler_bucket` |
| tempo | `gcs_bucket` |
| pyroscope | `gcs_bucket` |

**Azure container requirements per module:**

| Module | Required containers |
| --- | --- |
| mimir | `azure_storage_account`, `azure_blocks_container`, `azure_ruler_container`, `azure_alertmanager_container` |
| loki | `azure_storage_account`, `azure_chunks_container`, `azure_ruler_container` |
| tempo | `azure_storage_account`, `azure_container` |
| pyroscope | `azure_storage_account`, `azure_container` |

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

### S3 credentials secret

Instead of passing `s3_access_key` and `s3_secret_key` as plain text, you can reference a pre-existing Kubernetes Secret. The module injects the credentials as environment variables rather than embedding them in Helm values.

```hcl
storage = {
  backend                = "s3"
  s3_blocks_bucket       = "mimir-blocks"
  s3_ruler_bucket        = "mimir-ruler"
  s3_alertmanager_bucket = "mimir-alertmanager"
  s3_region              = "eu-west-1"

  s3_credentials_secret = {
    name             = "my-s3-secret"       # name of the pre-existing Secret
    access_key_field = "access-key"         # key inside the Secret (default: "access-key")
    secret_key_field = "secret-key"         # key inside the Secret (default: "secret-key")
  }
}
```

The same `s3_credentials_secret` variable is available on `modules/loki` and `modules/tempo`. To share one Secret across all three modules, pass the same `name` to each.

Three credential modes are supported — use whichever fits your environment:

| Mode | How to configure |
| --- | --- |
| IRSA / Workload Identity | Leave `s3_access_key`, `s3_secret_key`, and `s3_credentials_secret` all unset; provide `service_account_annotations` |
| Plain-text keys | Set `s3_access_key` and `s3_secret_key` directly; the module creates a Secret automatically |
| Pre-existing Secret | Set `s3_credentials_secret`; leave `s3_access_key` and `s3_secret_key` unset |

### Sharing one S3 bucket across Mimir storage types (Mimir only)

By default Mimir requires three separate S3 buckets (blocks, ruler, alertmanager). If you prefer a single bucket, use the `s3_blocks_prefix`, `s3_ruler_prefix`, and `s3_alertmanager_prefix` variables to isolate each storage type under a distinct key prefix.

```hcl
storage = {
  backend                = "s3"
  s3_blocks_bucket       = "mimir-shared"
  s3_ruler_bucket        = "mimir-shared"
  s3_alertmanager_bucket = "mimir-shared"
  s3_region              = "eu-west-1"
  s3_blocks_prefix       = "blocks"
  s3_ruler_prefix        = "ruler"
  s3_alertmanager_prefix = "alertmanager"
}
```

### Sharing one S3 bucket across Mimir, Tempo, and Pyroscope

Tempo and Pyroscope each expose a single `storage.s3_key_prefix` variable, so all three signal stores can share one bucket alongside Mimir:

```hcl
# mimir module
storage = {
  backend                = "s3"
  s3_blocks_bucket       = "observability-shared"
  s3_ruler_bucket        = "observability-shared"
  s3_alertmanager_bucket = "observability-shared"
  s3_region              = "eu-west-1"
  s3_blocks_prefix       = "mimir-blocks"
  s3_ruler_prefix        = "mimir-ruler"
  s3_alertmanager_prefix = "mimir-alertmanager"
}

# tempo module
storage = {
  backend       = "s3"
  s3_bucket     = "observability-shared"
  s3_region     = "eu-west-1"
  s3_key_prefix = "tempo"
}

# pyroscope module
storage = {
  backend       = "s3"
  s3_bucket     = "observability-shared"
  s3_region     = "eu-west-1"
  s3_key_prefix = "pyroscope"
}
```

> **Loki has no equivalent.** Loki's `storage_config` does not support an S3 object-key prefix upstream ([grafana/loki#5889](https://github.com/grafana/loki/issues/5889) is still open) — the `chunks`/`ruler` buckets it writes to must be dedicated to Loki, not shared with Mimir/Tempo/Pyroscope.

### S3 endpoint format

All three modules (mimir, loki, tempo) strip `https://` and `http://` from `s3_endpoint` automatically before passing the value to the underlying Helm chart. Either format is accepted:

```hcl
s3_endpoint = "fsn1.your-objectstorage.com"        # hostname only — preferred
s3_endpoint = "https://fsn1.your-objectstorage.com" # scheme stripped automatically
```

---

## Architecture

```text
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
| Alloy | OTel-native collector (successor to Grafana Agent) — River/Alloy pipeline config |
| Pyroscope | Continuous profiling storage and query — CPU, memory, goroutines, heap |
| cert-manager | TLS certificate issuance for ingress |
| prometheus-rules | Prometheus alert rules and Alertmanager receivers |
| grafana-rules | Grafana-managed alert rules and contact points |

---

## Troubleshooting

### "Endpoint url cannot have fully qualified paths"

This error is produced by the MinIO SDK when `s3_endpoint` is passed with a scheme (`https://` or `http://`). All three modules strip the scheme automatically, so this error should not appear. If it does, verify that `s3_endpoint` contains only the hostname and optional port — no scheme prefix.

```hcl
# Correct
s3_endpoint = "fsn1.your-objectstorage.com"

# Also accepted — scheme is stripped automatically
s3_endpoint = "https://fsn1.your-objectstorage.com"
```

### Mimir bundled MinIO conflict

The `mimir-distributed` Helm chart ships with MinIO enabled by default upstream. This module disables it (`minio.enabled: false`) because the bundled MinIO injects its own S3 configuration that conflicts with external storage backends, producing the "fully qualified paths" error above. No action is required from callers — the module handles this automatically.

### `usage_stats` disabled in Mimir

Mimir's anonymous telemetry (`usage_stats`) is disabled by this module. When `usage_stats` is enabled and an S3-compatible endpoint is configured, Mimir attempts to send telemetry to a fully-qualified S3 path that triggers the MinIO SDK path validation error. Disabling it has no effect on Mimir's functionality.

### Wrong cluster targeted by `kubectl`

The `cert-manager` and `prometheus-rules` modules use `kubectl` via a `local-exec` provisioner. If the `KUBECONFIG` environment variable is set in your shell, it overrides the Terraform provider's `config_path`, causing `kubectl` to target a different cluster than the one Terraform is managing.

Set `kubeconfig_path` explicitly on both modules to pin them to the correct config file:

```hcl
module "cert_manager" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/cert-manager"
  cert_manager = {
    kubeconfig_path = "/path/to/your/kubeconfig"
  }
}

module "prometheus_rules" {
  source = "github.com/digitalis-io/terraform-k8s-monitoring//modules/prometheus-rules"
  prometheus_rules = {
    prometheus_release_id = module.prometheus.helm_release_id
    kubeconfig_path       = "/path/to/your/kubeconfig"
  }
}
```

---

## Support

This project is maintained by [Digitalis.io](https://digitalis.io). For support, visit [digitalis.io/contact](https://digitalis.io/contact).
