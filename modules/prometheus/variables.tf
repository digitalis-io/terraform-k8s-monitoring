variable "prometheus" {
  description = "kube-prometheus-stack configuration. All fields are optional with safe defaults."
  type = object({
    chart_version        = optional(string, "75.2.0")
    namespace            = optional(string, "monitoring")
    create_namespace     = optional(bool, true)
    grafana_enabled      = optional(bool, true)
    alertmanager_enabled = optional(bool, true)
    ingress_enabled      = optional(bool, false)
    ingress_host         = optional(string, "")
    ingress_class_name   = optional(string, "nginx")
    ingress_tls_secret   = optional(string, "")
    ingress_annotations  = optional(map(string), {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    })
    storage_size   = optional(string, "20Gi")
    storage_class  = optional(string, "")
    retention      = optional(string, "24h")

    # Mimir integration — leave empty to deploy standalone (no remote_write / Grafana datasource)
    mimir_remote_write_url = optional(string, "")
    mimir_datasource_url   = optional(string, "")

    resources = optional(object({
      requests_cpu    = optional(string, "200m")
      requests_memory = optional(string, "512Mi")
      limits_cpu      = optional(string, "2")
      limits_memory   = optional(string, "2Gi")
    }), {})
  })
  default = {}

  validation {
    condition     = !(var.prometheus.ingress_enabled && var.prometheus.ingress_host == "")
    error_message = "ingress_host is required when ingress_enabled is true."
  }
}
