variable "prometheus" {
  description = "kube-prometheus-stack configuration. All fields are optional with safe defaults."
  type = object({
    chart_version        = optional(string, "75.2.0")
    namespace            = optional(string, "monitoring")
    create_namespace     = optional(bool, true)
    grafana_enabled      = optional(bool, true)
    alertmanager_enabled = optional(bool, true)
    grafana_ingress = optional(object({
      enabled     = optional(bool, false)
      host        = optional(string, "")
      class_name  = optional(string, "traefik")
      tls_secret  = optional(string, "")
      annotations = optional(map(string), {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      })
    }), {})

    prometheus_ingress = optional(object({
      enabled     = optional(bool, false)
      host        = optional(string, "")
      class_name  = optional(string, "traefik")
      tls_secret  = optional(string, "")
      annotations = optional(map(string), {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      })
    }), {})

    alertmanager_ingress = optional(object({
      enabled     = optional(bool, false)
      host        = optional(string, "")
      class_name  = optional(string, "traefik")
      tls_secret  = optional(string, "")
      annotations = optional(map(string), {
        "cert-manager.io/cluster-issuer" = "selfsigned-cluster-issuer"
      })
    }), {})
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
    condition     = !(var.prometheus.grafana_ingress.enabled && var.prometheus.grafana_ingress.host == "")
    error_message = "grafana_ingress.host is required when grafana_ingress.enabled is true."
  }

  validation {
    condition     = !(var.prometheus.prometheus_ingress.enabled && var.prometheus.prometheus_ingress.host == "")
    error_message = "prometheus_ingress.host is required when prometheus_ingress.enabled is true."
  }

  validation {
    condition     = !(var.prometheus.alertmanager_ingress.enabled && var.prometheus.alertmanager_ingress.host == "")
    error_message = "alertmanager_ingress.host is required when alertmanager_ingress.enabled is true."
  }
}
