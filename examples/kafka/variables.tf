variable "kafka_brokers" {
  description = "Kafka bootstrap address(es) the collectors produce to and consume from, e.g. \"my-kafka-bootstrap.kafka.svc.cluster.local:9092\" (comma-separated for multiple). The broker is not created by this example."
  type        = string
}

variable "mimir" {
  description = "Mimir configuration passed through to the module."
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
  description = "OpenTelemetry Collector configuration shared by the producer and consumer collectors."
  type        = any
  default     = {}
}

variable "pyroscope" {
  description = "Pyroscope configuration passed through to the module."
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
  description = "Domain name to use for the Grafana Ingress."
  type        = string
  default     = ""
}
