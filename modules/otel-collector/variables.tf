variable "otel" {
  description = "OpenTelemetry Collector configuration. All fields are optional with safe defaults."
  type = object({
    chart_version         = optional(string, "0.158.2")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    mode                  = optional(string, "daemonset") # daemonset | deployment

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
