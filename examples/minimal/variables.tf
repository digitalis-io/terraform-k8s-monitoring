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

variable "ingress_domain" {
  description = "Domain name to use for the Ingress"
  type        = string
  default     = "91.92.225.202.nip.io"
}