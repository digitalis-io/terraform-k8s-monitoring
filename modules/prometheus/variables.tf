variable "prometheus" {
  description = "kube-prometheus-stack configuration. All fields are optional with safe defaults."
  type = object({
    chart_version         = optional(string, "86.3.2")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    grafana_enabled       = optional(bool, true)
    alertmanager_enabled  = optional(bool, true)
    grafana_ingress = optional(object({
      enabled    = optional(bool, false)
      host       = optional(string, "")
      class_name = optional(string, "traefik")
      tls_secret = optional(string, "")
      annotations = optional(map(string), {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      })
    }), {})

    prometheus_ingress = optional(object({
      enabled    = optional(bool, false)
      host       = optional(string, "")
      class_name = optional(string, "traefik")
      tls_secret = optional(string, "")
      annotations = optional(map(string), {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      })
    }), {})

    alertmanager_ingress = optional(object({
      enabled    = optional(bool, false)
      host       = optional(string, "")
      class_name = optional(string, "traefik")
      tls_secret = optional(string, "")
      annotations = optional(map(string), {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      })
    }), {})
    storage_size  = optional(string, "20Gi")
    storage_class = optional(string, "")
    retention     = optional(string, "24h")

    # Mimir integration — leave empty to deploy standalone (no remote_write / Grafana datasource)
    mimir_remote_write_url = optional(string, "")
    mimir_datasource_url   = optional(string, "")
    # Tenant ID for the X-Scope-OrgID header sent to Mimir. Wire from module.mimir.tenant_id.
    mimir_tenant_id = optional(string, "anonymous")

    # Loki integration — wire from module.loki.datasource_url
    loki_datasource_url = optional(string, "")
    # Tempo integration — wire from module.tempo.datasource_url
    tempo_datasource_url = optional(string, "")
    # Loki -> Tempo correlation. Structured-metadata/label key on Loki logs
    # holding the trace id; used to build a Grafana derived field that links a
    # log line to its trace in Tempo. Only active when both loki_datasource_url
    # and tempo_datasource_url are set. OTLP-ingested logs expose this as the
    # structured-metadata field "trace_id" by default. Set "" to disable the link.
    loki_trace_id_field = optional(string, "trace_id")
    # Pyroscope integration — wire from module.pyroscope.datasource_url
    pyroscope_datasource_url = optional(string, "")

    # ClickHouse integration — configure the grafana-clickhouse-datasource plugin
    clickhouse_datasource = optional(object({
      host     = optional(string, "")
      port     = optional(number, 9000)
      database = optional(string, "observability")
      username = optional(string, "default")
      password = optional(string, "")
      secure   = optional(bool, false)

      # OTel schema — matches tables created by the otel-collector ClickHouse exporter
      logs_otel_enabled    = optional(bool, true)
      logs_default_table   = optional(string, "otel_logs")
      traces_otel_enabled  = optional(bool, true)
      traces_default_table = optional(string, "otel_traces")
    }), null)

    # Grafana plugins to install. Defaults include common community panels.
    grafana_plugins = optional(list(string), [
      "digrich-bubblechart-panel",
      "grafana-clock-panel",
      "btplc-status-dot-panel",
      "grafana-piechart-panel",
      "grafana-llm-app",
      "grafana-clickhouse-datasource",
    ])

    # Grafana dashboard IDs to import from grafana.com (in addition to the bundled JSON dashboards).
    # Each entry: { gnet_id = 1860, revision = 37, datasource = "Mimir" }
    # revision defaults to 1 if omitted; datasource defaults to "Mimir".
    grafana_dashboard_imports = optional(list(object({
      gnet_id    = number
      revision   = optional(number, 1)
      datasource = optional(string, "Mimir")
      })), [
      { gnet_id = 1860, revision = 37, datasource = "Mimir" }
    ])

    # Additional dashboard JSON files supplied by the caller.
    # key = filename (e.g. "my-app.json"), value = JSON content via file().
    # Merged with the bundled dashboards in modules/prometheus/dashboards/.
    # Example: { "my-app.json" = file("${path.module}/dashboards/my-app.json") }
    extra_dashboards = optional(map(string), {})

    resources = optional(object({
      requests_cpu    = optional(string, "200m")
      requests_memory = optional(string, "512Mi")
      limits_cpu      = optional(string, "2")
      limits_memory   = optional(string, "2Gi")
    }), {})
  })
  default = {}

  validation {
    condition = !(var.prometheus.grafana_ingress.enabled && (
      var.prometheus.grafana_ingress.host == "" ||
      !can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.prometheus.grafana_ingress.host))
    ))
    error_message = "grafana_ingress.host must be a valid RFC 1123 hostname (e.g. grafana.example.com) when grafana_ingress.enabled is true."
  }

  validation {
    condition = !(var.prometheus.prometheus_ingress.enabled && (
      var.prometheus.prometheus_ingress.host == "" ||
      !can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.prometheus.prometheus_ingress.host))
    ))
    error_message = "prometheus_ingress.host must be a valid RFC 1123 hostname (e.g. prometheus.example.com) when prometheus_ingress.enabled is true."
  }

  validation {
    condition = !(var.prometheus.alertmanager_ingress.enabled && (
      var.prometheus.alertmanager_ingress.host == "" ||
      !can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.prometheus.alertmanager_ingress.host))
    ))
    error_message = "alertmanager_ingress.host must be a valid RFC 1123 hostname (e.g. alertmanager.example.com) when alertmanager_ingress.enabled is true."
  }
}
