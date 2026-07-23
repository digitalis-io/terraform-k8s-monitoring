variable "kafka_broker" {
  description = "External Kafka bootstrap address (host:port) backing Mimir ingest storage. Empty deploys the chart's bundled demo Kafka (single broker, not for production)."
  type        = string
  default     = ""
}

variable "kafka_partitions" {
  description = "auto_create_topic_default_partitions for the Mimir ingest topic. Must be >= the maximum ingester replicas in a zone. 0 keeps the chart default."
  type        = number
  default     = 0
}

variable "mimir" {
  description = "Mimir configuration passed through to the module. The Kafka ingest block is set in main.tf."
  type        = any
  default     = {}
}

variable "prometheus" {
  description = "Prometheus configuration passed through to the module."
  type        = any
  default     = {}
}
