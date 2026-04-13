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
