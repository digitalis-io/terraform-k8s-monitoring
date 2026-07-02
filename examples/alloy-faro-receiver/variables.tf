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

variable "alloy" {
  description = "Grafana Alloy (OTLP daemonset collector) configuration passed through to the module."
  type        = any
  default     = {}
}

variable "faro_receiver" {
  description = "Grafana Alloy (Faro receiver) configuration passed through to the module. Merged over the faro_receiver defaults below — set ingress here to expose it to browsers outside the cluster."
  type        = any
  default     = {}
}
