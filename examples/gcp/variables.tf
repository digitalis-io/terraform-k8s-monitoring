variable "kubeconfig_path" {
  description = "Absolute path to the kubeconfig file. Tilde (~) is not expanded — use $HOME or a full path."
  type        = string
  default     = ""
}

# -- GCP Workload Identity -----------------------------------------------------
# Pre-create these Google Service Accounts with Storage Object Admin permissions
# on their respective buckets, and bind them to Kubernetes service accounts via
# Workload Identity.

variable "mimir_gsa_email" {
  description = "Google Service Account email for the Mimir Kubernetes service account (Workload Identity). Must have Storage Object Admin on the Mimir GCS buckets."
  type        = string
}

variable "loki_gsa_email" {
  description = "Google Service Account email for the Loki Kubernetes service account (Workload Identity). Must have Storage Object Admin on the Loki GCS buckets."
  type        = string
}

variable "tempo_gsa_email" {
  description = "Google Service Account email for the Tempo Kubernetes service account (Workload Identity). Must have Storage Object Admin on the Tempo GCS bucket."
  type        = string
}

# -- Bucket names (pre-create these before terraform apply) --------------------

variable "mimir_blocks_bucket" {
  description = "GCS bucket for Mimir block storage."
  type        = string
}

variable "mimir_ruler_bucket" {
  description = "GCS bucket for Mimir ruler storage."
  type        = string
}

variable "mimir_alertmanager_bucket" {
  description = "GCS bucket for Mimir Alertmanager storage."
  type        = string
}

variable "loki_chunks_bucket" {
  description = "GCS bucket for Loki chunk storage."
  type        = string
}

variable "loki_ruler_bucket" {
  description = "GCS bucket for Loki ruler storage."
  type        = string
}

variable "tempo_bucket" {
  description = "GCS bucket for Tempo trace storage."
  type        = string
}

# -- Optional ingress ---------------------------------------------------------

variable "ingress_domain" {
  description = "Base domain for Grafana ingress. Leave empty to disable ingress. Grafana will be available at grafana.<domain>."
  type        = string
  default     = ""
}

variable "ingress_class_name" {
  description = "Ingress class name for the Grafana ingress resource."
  type        = string
  default     = "gce"
}

# -- Optional alerting ---------------------------------------------------------

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications. Leave empty to disable Slack alerts."
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel to send alerts to."
  type        = string
  default     = "#alerts"
}

variable "pagerduty_routing_key" {
  description = "PagerDuty Events API v2 routing key. Leave empty to disable PagerDuty alerts."
  type        = string
  default     = ""
  sensitive   = true
}
