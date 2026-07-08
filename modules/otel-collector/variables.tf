variable "otel" {
  description = "OpenTelemetry Collector configuration. All fields are optional with safe defaults."
  type = object({
    chart_version         = optional(string, "0.158.2")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    mode                  = optional(string, "daemonset") # daemonset | deployment
    # Helm release name. Override when running two collectors in one namespace
    # (e.g. a "deployment" gateway plus a "daemonset" log/host agent).
    release_name = optional(string, "otel")

    # Wire from sibling module outputs
    tempo_endpoint           = optional(string, "")          # OTLP gRPC :4317 -- use module.tempo.otlp_grpc_endpoint
    mimir_endpoint           = optional(string, "")          # remote_write URL -- use module.mimir.remote_write_endpoint
    mimir_tenant_id          = optional(string, "anonymous") # X-Scope-OrgID header -- wire from module.mimir.tenant_id
    loki_endpoint            = optional(string, "")          # Loki push :3100 -- use module.loki.datasource_url
    clickhouse_endpoint      = optional(string, "")          # ClickHouse HTTP :8123 -- use module.clickhouse.http_endpoint
    clickhouse_username      = optional(string, "")          # ClickHouse username for OTLP/ClickHouse exporter
    clickhouse_password      = optional(string, "")          # ClickHouse password for OTLP/ClickHouse exporter
    clickhouse_database      = optional(string, "otel")      # ClickHouse database for OTLP/ClickHouse exporter
    clickhouse_create_schema = optional(bool, true)          # auto-create DB/tables on startup
    clickhouse_cluster       = optional(string, "")          # cluster name -> ON CLUSTER DDL (creates tables on all nodes)
    clickhouse_table_engine  = optional(string, "")          # e.g. ReplicatedMergeTree (pair with clickhouse_cluster for replication)

    # Structured-log parsing for the daemonset `filelog` receiver.
    # Promotes trace context and severity from JSON pod logs into native OTel
    # fields (fills ClickHouse otel_logs.TraceId/SpanId/SeverityText and enables
    # log<->trace correlation). Only applies in mode = "daemonset".
    log_parsing = optional(object({
      # Master switch for the json_parser operator. When false, the filelog
      # receiver uses only the `container` operator (bodies stay opaque).
      json_enabled = optional(bool, true)

      # Raw OTel filelog `if` expression that guards JSON parsing, so plain-text
      # logs pass through untouched. Default matches lines whose (leading-space-
      # trimmed) body starts with '{'. Advanced: this is an expr-lang expression
      # rendered inside a single-quoted YAML scalar -- mind expr/YAML escaping if
      # you override it (e.g. use hasPrefix(body, "{") to avoid regex backslashes).
      json_match_expr = optional(string, "body matches \"^\\\\s*[{]\"")

      # JSON field mapped to SeverityText/SeverityNumber. Empty ("") disables
      # severity mapping.
      severity_field = optional(string, "level")

      # Promote trace_id/span_id JSON fields into the log record's trace context.
      # Requires json_enabled = true.
      trace_enabled  = optional(bool, true)
      trace_id_field = optional(string, "trace_id")
      span_id_field  = optional(string, "span_id")
    }), {})

    image = optional(object({
      # contrib includes prometheusremotewrite and loki exporters required for Mimir/Loki forwarding
      repository  = optional(string, "otel/opentelemetry-collector-contrib")
      tag         = optional(string, "") # empty = chart appVersion
      pull_policy = optional(string, "IfNotPresent")
    }), {})

    resources = optional(object({
      requests_cpu    = optional(string, "300m")
      requests_memory = optional(string, "256Mi")
      limits_cpu      = optional(string, "500m")
      limits_memory   = optional(string, "512Mi")
    }), {})

    # Annotations to add to the OpenTelemetry Collector ServiceAccount.
    # Use this for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/otel" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "otel@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})

    # Pod scheduling. nodeSelector pins the collector to matching nodes;
    # tolerations let it schedule onto tainted pools (e.g. GKE's automatic
    # kubernetes.io/arch=arm64:NoSchedule taint on Arm node pools).
    node_selector = optional(map(string), {})
    tolerations = optional(list(object({
      key      = optional(string, "")
      operator = optional(string, "Equal")
      value    = optional(string, "")
      effect   = optional(string, "")
    })), [])

    operator = optional(object({
      enabled                    = optional(bool, false)
      chart_version              = optional(string, "0.116.0")
      collector_image_repository = optional(string, "otel/opentelemetry-collector-k8s")
      cert_manager_enabled       = optional(bool, false)
      auto_generate_cert_enabled = optional(bool, true)
      extra_args                 = optional(list(string), [])

      # Go auto-instrumentation (eBPF-based; requires Linux kernel >=4.19 and privileged DaemonSet)
      go_instrumentation_enabled = optional(bool, false)
      go_instrumentation_image   = optional(string, "") # defaults to chart appVersion image when empty
    }), {})
  })
  default = {}

  validation {
    condition     = contains(["daemonset", "deployment"], var.otel.mode)
    error_message = "mode must be one of: daemonset, deployment."
  }
}
