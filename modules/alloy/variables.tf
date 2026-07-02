variable "alloy" {
  description = "Grafana Alloy configuration. All fields are optional with safe defaults."
  type = object({
    # Chart version from https://artifacthub.io/packages/helm/grafana/alloy
    chart_version         = optional(string, "0.12.5")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)

    # Controller type determines the Kubernetes workload kind.
    # "daemonset"   — one pod per node; use for log/metric collection from every node
    # "deployment"  — fixed replica count; use for gateway/aggregation role
    # "statefulset" — stable pod identity; use when Alloy writes WAL to persistent storage
    controller_type = optional(string, "daemonset")

    # Number of replicas; ignored when controller_type = "daemonset"
    replicas = optional(number, 1)

    # Alloy pipeline configuration in River/Alloy syntax.
    # Written verbatim into the Helm chart's alloy.configMap.content value.
    # When empty, the module renders a built-in default config that wires non-empty
    # sibling endpoints automatically. Override with a full config string to take
    # complete control of all pipeline components.
    alloy_config = optional(string, "")

    # Persistence for WAL state — only meaningful when controller_type = "statefulset"
    persistence = optional(object({
      enabled       = optional(bool, false)
      storage_class = optional(string, "") # empty = cluster default
      size          = optional(string, "10Gi")
      access_mode   = optional(string, "ReadWriteOnce")
    }), {})

    resources = optional(object({
      requests_cpu    = optional(string, "100m")
      requests_memory = optional(string, "128Mi")
      limits_cpu      = optional(string, "500m")
      limits_memory   = optional(string, "512Mi")
    }), {})

    ingress = optional(object({
      enabled     = optional(bool, false)
      host        = optional(string, "")
      class_name  = optional(string, "nginx")
      tls_secret  = optional(string, "")
      annotations = optional(map(string), {})
    }), {})

    # Sibling-module integration — pass outputs from other modules directly.
    # Wired into the built-in default config when alloy_config = "".
    # When alloy_config is non-empty these are ignored; embed endpoints in your config string.
    loki_endpoint      = optional(string, "") # e.g. module.loki.datasource_url
    tempo_endpoint     = optional(string, "") # e.g. module.tempo.otlp_grpc_endpoint
    mimir_endpoint     = optional(string, "") # e.g. module.mimir.remote_write_endpoint
    mimir_tenant_id    = optional(string, "anonymous")
    pyroscope_endpoint = optional(string, "") # e.g. module.pyroscope.push_url
    otel_grpc_endpoint = optional(string, "") # e.g. module.otel.otlp_grpc_endpoint

    # Annotations added to the Alloy ServiceAccount.
    # Use for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/alloy" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "alloy@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})

    # Arbitrary extra Helm values merged last; highest precedence over the template.
    extra_values = optional(string, "")

    # Sensitive-data (PII) processor — hashes or deletes matched attributes on logs,
    # traces, and metrics before export. See https://opentelemetry.io/docs/security/handling-sensitive-data/
    # Enabled by default with a financial-institution-oriented ruleset (credit card
    # numbers, CVV, passwords/secrets/tokens, SSNs, IBANs/bank accounts, email
    # addresses). Only wired into the built-in config; a non-empty alloy_config
    # takes full control and must handle redaction itself.
    sensitive_data = optional(object({
      enabled               = optional(bool, true)
      action                = optional(string, "hash") # "hash" or "delete"
      default_rules_enabled = optional(bool, true)
      custom_rules          = optional(map(string), {}) # { "attribute.name" = "hash" | "delete" }
      salt                  = optional(string, "")      # mixed into the hash for deterministic, non-rainbow-table-able output
    }), {})
  })
  default = {}

  validation {
    condition     = contains(["daemonset", "deployment", "statefulset"], var.alloy.controller_type)
    error_message = "controller_type must be one of: daemonset, deployment, statefulset."
  }

  validation {
    condition     = !try(var.alloy.ingress.enabled, false) || try(var.alloy.ingress.host, "") != ""
    error_message = "ingress.host is required when ingress.enabled = true."
  }

  validation {
    condition     = contains(["hash", "delete"], try(var.alloy.sensitive_data.action, "hash"))
    error_message = "sensitive_data.action must be 'hash' or 'delete'."
  }

  validation {
    condition = alltrue([
      for action in values(try(var.alloy.sensitive_data.custom_rules, {})) : contains(["hash", "delete"], action)
    ])
    error_message = "sensitive_data.custom_rules values must be 'hash' or 'delete'."
  }
}
