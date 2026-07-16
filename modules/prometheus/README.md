<div align="center">

<a href="https://digitalis.io/"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="320"/></a>

# kube-prometheus-stack module

**Deploys kube-prometheus-stack (Prometheus, Grafana, Alertmanager) with datasource provisioning for Mimir, Loki, Tempo and Pyroscope, component toggles and an optional external Grafana database.**

</div>

Part of [terraform-k8s-monitoring](../../README.md). See the root README for full usage, examples and storage configuration guidance.

## Reference

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.17 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.36 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.prometheus](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_config_map.grafana_dashboard](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_namespace.prometheus](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.clickhouse_datasource](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.grafana_database](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prometheus"></a> [prometheus](#input\_prometheus) | kube-prometheus-stack configuration. All fields are optional with safe defaults. | <pre>object({<br>    chart_version         = optional(string, "86.3.2")<br>    namespace             = optional(string, "monitoring")<br>    namespace_labels      = optional(map(string), {})<br>    namespace_annotations = optional(map(string), {})<br>    create_namespace      = optional(bool, true)<br>    # Helm release readiness. wait/wait_for_jobs block apply until resources are<br>    # ready; set wait = false for async/GitOps rollouts.<br>    wait                 = optional(bool, true)<br>    wait_for_jobs        = optional(bool, true)<br>    timeout              = optional(number, 600)<br>    grafana_enabled      = optional(bool, true)<br>    alertmanager_enabled = optional(bool, true)<br><br>    # Number of Grafana replicas. Values > 1 require grafana_database (external<br>    # PostgreSQL/MySQL) — the default SQLite backend cannot be shared across pods.<br>    grafana_replicas = optional(number, 1)<br><br>    # Per-component toggles. Disable any subset to slim the stack (e.g. set<br>    # prometheus_enabled/prometheus_operator_enabled/kube_state_metrics_enabled/<br>    # node_exporter_enabled/default_rules_enabled = false with grafana_enabled =<br>    # true for a Grafana-only deployment). CRDs are always installed by the chart<br>    # and are unaffected by these toggles.<br>    prometheus_enabled          = optional(bool, true)<br>    prometheus_operator_enabled = optional(bool, true)<br>    kube_state_metrics_enabled  = optional(bool, true)<br>    node_exporter_enabled       = optional(bool, true)<br>    default_rules_enabled       = optional(bool, true)<br>    grafana_ingress = optional(object({<br>      enabled    = optional(bool, false)<br>      host       = optional(string, "")<br>      class_name = optional(string, "traefik")<br>      tls_secret = optional(string, "")<br>      annotations = optional(map(string), {<br>        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"<br>      })<br>    }), {})<br><br>    prometheus_ingress = optional(object({<br>      enabled    = optional(bool, false)<br>      host       = optional(string, "")<br>      class_name = optional(string, "traefik")<br>      tls_secret = optional(string, "")<br>      annotations = optional(map(string), {<br>        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"<br>      })<br>    }), {})<br><br>    alertmanager_ingress = optional(object({<br>      enabled    = optional(bool, false)<br>      host       = optional(string, "")<br>      class_name = optional(string, "traefik")<br>      tls_secret = optional(string, "")<br>      annotations = optional(map(string), {<br>        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"<br>      })<br>    }), {})<br>    storage_size  = optional(string, "20Gi")<br>    storage_class = optional(string, "")<br>    retention     = optional(string, "24h")<br><br>    # External database backend for Grafana. Leave null (default) to use the<br>    # chart's built-in SQLite (ephemeral unless the pod has persistence). Set to<br>    # move Grafana's state (dashboards, users, prefs) into PostgreSQL or MySQL —<br>    # required for running more than one Grafana replica.<br>    #<br>    # Supply the password one of two ways:<br>    #   * password        — plaintext; the module creates a Secret from it.<br>    #   * password_secret — reference an existing Secret (never commit plaintext).<br>    # Providing neither leaves GF_DATABASE_PASSWORD unset (passwordless / IAM auth).<br>    grafana_database = optional(object({<br>      type     = optional(string, "postgres") # "postgres" | "mysql"<br>      host     = string                       # "host:port", e.g. "pg.db.svc:5432"<br>      name     = string<br>      user     = string<br>      password = optional(string, "")<br>      password_secret = optional(object({<br>        name  = string<br>        field = optional(string, "password")<br>      }), null)<br>      # PostgreSQL only: disable | require | verify-ca | verify-full. Ignored for mysql.<br>      ssl_mode = optional(string, "")<br>    }), null)<br><br>    # Mimir integration — leave empty to deploy standalone (no remote_write / Grafana datasource)<br>    mimir_remote_write_url = optional(string, "")<br>    mimir_datasource_url   = optional(string, "")<br>    # Tenant ID for the X-Scope-OrgID header sent to Mimir. Wire from module.mimir.tenant_id.<br>    mimir_tenant_id = optional(string, "anonymous")<br><br>    # Loki integration — wire from module.loki.datasource_url<br>    loki_datasource_url = optional(string, "")<br>    # Tempo integration — wire from module.tempo.datasource_url<br>    tempo_datasource_url = optional(string, "")<br>    # Loki -> Tempo correlation. Name of the trace-id field in the JSON log<br>    # body; used to build a Grafana derived field (regex matcher<br>    # '"<field>":"(\w+)"') that links a log line to its trace in Tempo. A regex<br>    # matcher against the body is used rather than a structured-metadata label<br>    # matcher, which the Grafana Logs Drilldown app does not resolve. Only active<br>    # when both loki_datasource_url and tempo_datasource_url are set. Set "" to<br>    # disable the link.<br>    loki_trace_id_field = optional(string, "trace_id")<br>    # Pyroscope integration — wire from module.pyroscope.datasource_url<br>    pyroscope_datasource_url = optional(string, "")<br>    # Trace -> profiles (Tempo -> Pyroscope). Default Pyroscope profile type<br>    # opened when jumping from a span to profiles. Only active when both<br>    # tempo_datasource_url and pyroscope_datasource_url are set. Set "" to<br>    # disable the trace-to-profiles link.<br>    tempo_profile_type_id = optional(string, "process_cpu:cpu:nanoseconds:cpu:nanoseconds")<br><br>    # ClickHouse integration — configure the grafana-clickhouse-datasource plugin<br>    clickhouse_datasource = optional(object({<br>      host     = optional(string, "")<br>      port     = optional(number, 9000)<br>      database = optional(string, "observability")<br>      username = optional(string, "default")<br>      # Supply the password one of two ways (mutually exclusive):<br>      #   * password        — plaintext; the module creates a Secret from it.<br>      #   * password_secret — reference an existing Secret (never commit plaintext).<br>      # Either way it is injected via Grafana's $__env{} expansion, never rendered<br>      # into secureJsonData in the Helm values. Neither set = no password.<br>      password = optional(string, "")<br>      password_secret = optional(object({<br>        name  = string<br>        field = optional(string, "password")<br>      }), null)<br>      secure = optional(bool, false)<br><br>      # OTel schema — matches tables created by the otel-collector ClickHouse exporter<br>      logs_otel_enabled    = optional(bool, true)<br>      logs_default_table   = optional(string, "otel_logs")<br>      traces_otel_enabled  = optional(bool, true)<br>      traces_default_table = optional(string, "otel_traces")<br>    }), null)<br><br>    # Grafana plugins to install. Defaults include common community panels.<br>    grafana_plugins = optional(list(string), [<br>      "digrich-bubblechart-panel",<br>      "grafana-clock-panel",<br>      "btplc-status-dot-panel",<br>      "grafana-piechart-panel",<br>      "grafana-llm-app",<br>      "grafana-clickhouse-datasource",<br>    ])<br><br>    # Grafana dashboard IDs to import from grafana.com (in addition to the bundled JSON dashboards).<br>    # Each entry: { gnet_id = 1860, revision = 37, datasource = "Mimir" }<br>    # revision defaults to 1 if omitted; datasource defaults to "Mimir".<br>    grafana_dashboard_imports = optional(list(object({<br>      gnet_id    = number<br>      revision   = optional(number, 1)<br>      datasource = optional(string, "Mimir")<br>      })), [<br>      { gnet_id = 1860, revision = 37, datasource = "Mimir" }<br>    ])<br><br>    # Additional dashboard JSON files supplied by the caller.<br>    # key = filename (e.g. "my-app.json"), value = JSON content via file().<br>    # Merged with the bundled dashboards in modules/prometheus/dashboards/.<br>    # Example: { "my-app.json" = file("${path.module}/dashboards/my-app.json") }<br>    extra_dashboards = optional(map(string), {})<br><br>    resources = optional(object({<br>      requests_cpu    = optional(string, "200m")<br>      requests_memory = optional(string, "512Mi")<br>      limits_cpu      = optional(string, "2")<br>      limits_memory   = optional(string, "2Gi")<br>    }), {})<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_grafana_service"></a> [grafana\_service](#output\_grafana\_service) | In-cluster URL for the Grafana service. |
| <a name="output_helm_release_id"></a> [helm\_release\_id](#output\_helm\_release\_id) | Helm release ID — use as prometheus\_release\_id in modules/prometheus-rules to enforce apply order. |
| <a name="output_helm_release_name"></a> [helm\_release\_name](#output\_helm\_release\_name) | Name of the Helm release. |
| <a name="output_helm_release_version"></a> [helm\_release\_version](#output\_helm\_release\_version) | Deployed chart version. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace where kube-prometheus-stack is deployed. |

---

Maintained by [Digitalis.io](https://digitalis.io) — support at [digitalis.io/contact](https://digitalis.io/contact).
