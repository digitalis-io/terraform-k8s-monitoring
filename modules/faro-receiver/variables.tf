variable "faro_receiver" {
  description = "Grafana Faro real-user-monitoring (RUM) receiver configuration. All fields are optional with safe defaults."
  type = object({
    # Deployed via the grafana/alloy Helm chart configured with Alloy's
    # faro.receiver component — Grafana does not publish a standalone "faro"
    # Helm chart. Chart version from https://artifacthub.io/packages/helm/grafana/alloy
    chart_version         = optional(string, "0.12.5")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)

    # The Faro receiver is a stateless RUM ingestion gateway; only "deployment" is supported.
    controller_type = optional(string, "deployment")
    replicas        = optional(number, 2)

    # HTTP port the Faro receiver listens on for browser SDK payloads.
    port = optional(number, 12347)

    # Alloy pipeline configuration in River/Alloy syntax.
    # Written verbatim into the Helm chart's alloy.configMap.content value.
    # When empty, the module renders a built-in default faro.receiver config that
    # wires non-empty sibling endpoints automatically. Override with a full config
    # string to take complete control of the pipeline.
    faro_config = optional(string, "")

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
    # Wired into the built-in default config when faro_config = "".
    # When faro_config is non-empty these are ignored; embed endpoints in your config string.
    # No Mimir wiring: Alloy's faro.receiver component only emits logs and traces,
    # it has no metrics output to route to a remote-write target.
    tempo_endpoint = optional(string, "") # e.g. module.tempo.otlp_grpc_endpoint
    loki_endpoint  = optional(string, "") # e.g. module.loki.datasource_url

    # Annotations added to the Faro receiver ServiceAccount.
    # Use for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module.
    service_account_annotations = optional(map(string), {})

    # Arbitrary extra Helm values merged last; highest precedence over the template.
    extra_values = optional(string, "")
  })
  default = {}

  validation {
    condition     = var.faro_receiver.controller_type == "deployment"
    error_message = "controller_type must be 'deployment' — StatefulSet and DaemonSet are not applicable for stateless RUM reception."
  }

  validation {
    condition     = !try(var.faro_receiver.ingress.enabled, false) || try(var.faro_receiver.ingress.host, "") != ""
    error_message = "ingress.host is required when ingress.enabled = true."
  }
}
