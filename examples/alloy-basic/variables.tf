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

variable "mimir" {
  description = "Mimir configuration passed through to the module."
  type        = any
  default     = {}
}

variable "alloy" {
  description = "Grafana Alloy configuration passed through to the module."
  type        = any
  default     = {}
}
