variable "alloy" {
  description = "Grafana Alloy configuration. All fields are optional with safe defaults."
  type = object({
    # Chart version from https://artifacthub.io/packages/helm/grafana/alloy
    chart_version         = optional(string, "0.12.5")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)

    # Helm release name. Override when deploying more than one Alloy-based
    # release into the same namespace (e.g. a daemonset collector alongside a
    # deployment-mode gateway) so they don't collide.
    release_name = optional(string, "alloy")

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

    # Opt-in Grafana Faro real-user-monitoring (RUM) receiver. When enabled and
    # alloy_config is empty, the built-in default config wires Alloy's
    # faro.receiver component (instead of the OTLP receiver) listening on
    # `port`, forwarding logs to loki_endpoint and traces to tempo_endpoint.
    # faro.receiver has no metrics output, so mimir_endpoint is not used here.
    # Deploy a second module "alloy" instance with a distinct release_name for
    # a Faro gateway alongside a separate OTLP daemonset collector.
    faro_receiver = optional(object({
      enabled = optional(bool, false)
      port    = optional(number, 12347) # 1-65535
    }), {})

    # Additional container ports exposed on the Alloy pod/Service, beyond the
    # default OTLP gRPC/HTTP ports. Use when alloy_config wires up a component
    # that listens on its own port (e.g. Alloy's faro.receiver).
    extra_ports = optional(list(object({
      name        = string
      port        = number
      target_port = number
      protocol    = optional(string, "TCP")
    })), [])

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
    otel_grpc_endpoint = optional(string, "") # e.g. module.otel.otlp_grpc_endpoint -- fans out alongside mimir/loki/tempo_endpoint (set any combination for direct-only, otel-only, or dual-write). Only honored by the OTLP-receiver config (faro_receiver.enabled = false); the Faro branch always sends logs/traces direct to loki/tempo_endpoint.

    # Annotations added to the Alloy ServiceAccount.
    # Use for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/alloy" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "alloy@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})

    # Arbitrary extra Helm values merged last; highest precedence over the template.
    extra_values = optional(string, "")
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
    condition     = try(var.alloy.faro_receiver.port, 12347) > 0 && try(var.alloy.faro_receiver.port, 12347) <= 65535
    error_message = "faro_receiver.port must be a valid TCP port (1-65535)."
  }

  validation {
    # The grafana/alloy chart's ingress feature always targets a fixed Faro
    # port (ingress.faroPort) — it has no general-purpose routing for other
    # components, so enabling it without faro_receiver.enabled is dead config.
    condition     = !try(var.alloy.ingress.enabled, false) || try(var.alloy.faro_receiver.enabled, false)
    error_message = "ingress.enabled requires faro_receiver.enabled = true — the chart's ingress only ever routes to the Faro receiver port."
  }
}
