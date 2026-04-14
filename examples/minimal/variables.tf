variable "mimir" {
  description = "Mimir configuration passed through to the module. Overrides the defaults set in main.tf."
  type        = any
  default     = {}
}

variable "prometheus" {
  description = "Prometheus configuration passed through to the module."
  type        = any
  default     = {}
}

variable "loki" {
  description = "Loki configuration passed through to the module."
  type        = any
  default     = {}
}

variable "tempo" {
  description = "Tempo configuration passed through to the module."
  type        = any
  default     = {}
}

variable "otel" {
  description = "OpenTelemetry Collector configuration passed through to the module."
  type        = any
  default     = {}
}

variable "cert_manager" {
  description = "cert-manager configuration passed through to the module."
  type        = any
  default     = {}
}

variable "prometheus_rules" {
  description = "Prometheus alert rules and Alertmanager receiver configuration."
  type        = any
  default     = {}
}

variable "grafana_rules" {
  description = "Grafana-managed alert rules and notification contact points."
  type        = any
  default     = {}
}

variable "ingress_domain" {
  description = "Domain name to use for the Ingress"
  type        = string
  default     = ""
}