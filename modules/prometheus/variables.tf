variable "prometheus" {
  description = "kube-prometheus-stack configuration. All fields are optional with safe defaults."
  type = object({
    chart_version         = optional(string, "87.19.0")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    # Helm release readiness. wait/wait_for_jobs block apply until resources are
    # ready; set wait = false for async/GitOps rollouts.
    wait                 = optional(bool, true)
    wait_for_jobs        = optional(bool, true)
    timeout              = optional(number, 600)
    grafana_enabled      = optional(bool, true)
    alertmanager_enabled = optional(bool, true)

    # Number of Grafana replicas. Values > 1 require grafana_database (external
    # PostgreSQL/MySQL) — the default SQLite backend cannot be shared across pods.
    grafana_replicas = optional(number, 1)

    # Per-component toggles. Disable any subset to slim the stack (e.g. set
    # prometheus_enabled/prometheus_operator_enabled/kube_state_metrics_enabled/
    # node_exporter_enabled/default_rules_enabled = false with grafana_enabled =
    # true for a Grafana-only deployment). CRDs are always installed by the chart
    # and are unaffected by these toggles.
    prometheus_enabled          = optional(bool, true)
    prometheus_operator_enabled = optional(bool, true)
    kube_state_metrics_enabled  = optional(bool, true)
    node_exporter_enabled       = optional(bool, true)
    default_rules_enabled       = optional(bool, true)
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

    # External database backend for Grafana. Leave null (default) to use the
    # chart's built-in SQLite (ephemeral unless the pod has persistence). Set to
    # move Grafana's state (dashboards, users, prefs) into PostgreSQL or MySQL —
    # required for running more than one Grafana replica.
    #
    # Supply the password one of two ways:
    #   * password        — plaintext; the module creates a Secret from it.
    #   * password_secret — reference an existing Secret (never commit plaintext).
    # Providing neither leaves GF_DATABASE_PASSWORD unset (passwordless / IAM auth).
    grafana_database = optional(object({
      type     = optional(string, "postgres") # "postgres" | "mysql"
      host     = string                       # "host:port", e.g. "pg.db.svc:5432"
      name     = string
      user     = string
      password = optional(string, "")
      password_secret = optional(object({
        name  = string
        field = optional(string, "password")
      }), null)
      # PostgreSQL only: disable | require | verify-ca | verify-full. Ignored for mysql.
      ssl_mode = optional(string, "")
    }), null)

    # Mimir integration — leave empty to deploy standalone (no remote_write / Grafana datasource)
    mimir_remote_write_url = optional(string, "")
    mimir_datasource_url   = optional(string, "")
    # Tenant ID for the X-Scope-OrgID header sent to Mimir. Wire from module.mimir.tenant_id.
    mimir_tenant_id = optional(string, "anonymous")

    # Loki integration — wire from module.loki.datasource_url
    loki_datasource_url = optional(string, "")
    # Tempo integration — wire from module.tempo.datasource_url
    tempo_datasource_url = optional(string, "")
    # Loki -> Tempo correlation. Name of the trace-id field in the JSON log
    # body; used to build a Grafana derived field (regex matcher
    # '"<field>":"(\w+)"') that links a log line to its trace in Tempo. A regex
    # matcher against the body is used rather than a structured-metadata label
    # matcher, which the Grafana Logs Drilldown app does not resolve. Only active
    # when both loki_datasource_url and tempo_datasource_url are set. Set "" to
    # disable the link.
    loki_trace_id_field = optional(string, "trace_id")
    # Pyroscope integration — wire from module.pyroscope.datasource_url
    pyroscope_datasource_url = optional(string, "")
    # Trace -> profiles (Tempo -> Pyroscope). Default Pyroscope profile type
    # opened when jumping from a span to profiles. Only active when both
    # tempo_datasource_url and pyroscope_datasource_url are set. Set "" to
    # disable the trace-to-profiles link.
    tempo_profile_type_id = optional(string, "process_cpu:cpu:nanoseconds:cpu:nanoseconds")

    # ClickHouse integration — configure the grafana-clickhouse-datasource plugin
    clickhouse_datasource = optional(object({
      host     = optional(string, "")
      port     = optional(number, 9000)
      database = optional(string, "observability")
      username = optional(string, "default")
      # Supply the password one of two ways (mutually exclusive):
      #   * password        — plaintext; the module creates a Secret from it.
      #   * password_secret — reference an existing Secret (never commit plaintext).
      # Either way it is injected via Grafana's $__env{} expansion, never rendered
      # into secureJsonData in the Helm values. Neither set = no password.
      password = optional(string, "")
      password_secret = optional(object({
        name  = string
        field = optional(string, "password")
      }), null)
      secure = optional(bool, false)

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
    condition     = var.prometheus.grafana_replicas >= 1
    error_message = "grafana_replicas must be >= 1."
  }

  validation {
    condition     = var.prometheus.grafana_replicas <= 1 || var.prometheus.grafana_database != null
    error_message = "grafana_replicas > 1 requires grafana_database (external PostgreSQL/MySQL); SQLite cannot be shared across Grafana pods."
  }

  # try(..., true) guards the null-object case: OpenTofu <1.11 eagerly evaluates
  # both sides of `||`, so a `grafana_database == null || <access .attr>` guard
  # still errors ("Attempt to get attribute from null value") when the object is
  # null. try() catches that and treats an unset grafana_database as valid.
  validation {
    condition = try(
      var.prometheus.grafana_database == null ||
      contains(["postgres", "mysql"], var.prometheus.grafana_database.type),
      true
    )
    error_message = "grafana_database.type must be either \"postgres\" or \"mysql\"."
  }

  validation {
    condition = try(
      var.prometheus.grafana_database == null ||
      !(var.prometheus.grafana_database.password != "" && var.prometheus.grafana_database.password_secret != null),
      true
    )
    error_message = "grafana_database: set at most one of password or password_secret, not both."
  }

  validation {
    condition = try(
      var.prometheus.clickhouse_datasource == null ||
      !(var.prometheus.clickhouse_datasource.password != "" && var.prometheus.clickhouse_datasource.password_secret != null),
      true
    )
    error_message = "clickhouse_datasource: set at most one of password or password_secret, not both."
  }

  validation {
    condition = try(
      var.prometheus.grafana_database == null ||
      (var.prometheus.grafana_database.host != "" &&
        var.prometheus.grafana_database.name != "" &&
      var.prometheus.grafana_database.user != ""),
      true
    )
    error_message = "grafana_database requires non-empty host, name, and user."
  }

  validation {
    condition = try(
      var.prometheus.grafana_database == null ||
      can(regex("^[^:/\\s]+:[0-9]+$", var.prometheus.grafana_database.host)),
      true
    )
    error_message = "grafana_database.host must be in \"host:port\" form, e.g. \"pg.db.svc:5432\"."
  }

  validation {
    condition = try(
      var.prometheus.grafana_database == null ||
      var.prometheus.grafana_database.ssl_mode == "" ||
      var.prometheus.grafana_database.type == "postgres",
      true
    )
    error_message = "grafana_database.ssl_mode is only supported for type = \"postgres\"; leave it \"\" for mysql."
  }

  validation {
    condition = !(var.prometheus.alertmanager_ingress.enabled && (
      var.prometheus.alertmanager_ingress.host == "" ||
      !can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.prometheus.alertmanager_ingress.host))
    ))
    error_message = "alertmanager_ingress.host must be a valid RFC 1123 hostname (e.g. alertmanager.example.com) when alertmanager_ingress.enabled is true."
  }
}
