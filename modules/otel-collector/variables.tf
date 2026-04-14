variable "otel" {
  description = "OpenTelemetry Collector configuration. All fields are optional with safe defaults."
  type = object({
    chart_version         = optional(string, "0.150.0")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    mode                  = optional(string, "daemonset") # daemonset | deployment

    # Wire from sibling module outputs
    tempo_endpoint = optional(string, "") # OTLP gRPC :4317 -- use module.tempo.otlp_grpc_endpoint
    mimir_endpoint = optional(string, "") # remote_write URL -- use module.mimir.remote_write_endpoint
    loki_endpoint  = optional(string, "") # Loki push :3100 -- use module.loki.datasource_url

    image = optional(object({
      # contrib includes prometheusremotewrite and loki exporters required for Mimir/Loki forwarding
      repository  = optional(string, "otel/opentelemetry-collector-contrib")
      tag         = optional(string, "") # empty = chart appVersion
      pull_policy = optional(string, "IfNotPresent")
    }), {})

    resources = optional(object({
      requests_cpu    = optional(string, "100m")
      requests_memory = optional(string, "128Mi")
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
  })
  default = {}

  validation {
    condition     = contains(["daemonset", "deployment"], var.otel.mode)
    error_message = "mode must be one of: daemonset, deployment."
  }
}
