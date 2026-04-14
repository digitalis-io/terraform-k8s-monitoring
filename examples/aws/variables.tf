variable "kubeconfig_path" {
  description = "Absolute path to the kubeconfig file. Tilde (~) is not expanded — use $HOME or a full path."
  type        = string
  default     = ""
}

# -- AWS region ----------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where the S3 buckets are located."
  type        = string
}

# -- IRSA role ARNs ------------------------------------------------------------
# Pre-create these IAM roles with S3 permissions and IRSA trust policies.
# Each role must trust the EKS OIDC provider for the monitoring namespace.

variable "mimir_irsa_role_arn" {
  description = "IAM role ARN for the Mimir service account (IRSA). Must have read/write access to the Mimir S3 buckets."
  type        = string
}

variable "loki_irsa_role_arn" {
  description = "IAM role ARN for the Loki service account (IRSA). Must have read/write access to the Loki S3 buckets."
  type        = string
}

variable "tempo_irsa_role_arn" {
  description = "IAM role ARN for the Tempo service account (IRSA). Must have read/write access to the Tempo S3 bucket."
  type        = string
}

# -- Bucket names (pre-create these before terraform apply) --------------------

variable "mimir_blocks_bucket" {
  description = "S3 bucket for Mimir block storage."
  type        = string
}

variable "mimir_blocks_prefix" {
  description = "Optional S3 key prefix for Mimir block storage. Use to share a bucket across components."
  type        = string
  default     = ""
}

variable "mimir_ruler_bucket" {
  description = "S3 bucket for Mimir ruler storage."
  type        = string
}

variable "mimir_ruler_prefix" {
  description = "Optional S3 key prefix for Mimir ruler storage."
  type        = string
  default     = ""
}

variable "mimir_alertmanager_bucket" {
  description = "S3 bucket for Mimir Alertmanager storage."
  type        = string
}

variable "mimir_alertmanager_prefix" {
  description = "Optional S3 key prefix for Mimir Alertmanager storage."
  type        = string
  default     = ""
}

variable "loki_chunks_bucket" {
  description = "S3 bucket for Loki chunk storage."
  type        = string
}

variable "loki_ruler_bucket" {
  description = "S3 bucket for Loki ruler storage."
  type        = string
}

variable "tempo_bucket" {
  description = "S3 bucket for Tempo trace storage."
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
  default     = "alb"
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
