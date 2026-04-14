variable "kubeconfig_path" {
  description = "Absolute path to the kubeconfig file. Tilde (~) is not expanded — use $HOME or a full path."
  type        = string
  default     = ""
}

# ── S3-compatible object storage ────────────────────────────────────────────

variable "s3_endpoint" {
  description = "S3-compatible endpoint URL. Examples: Hetzner (https://<bucket>.fsn1.your-objectstorage.com), MinIO (http://minio.minio.svc:9000)."
  type        = string
}

variable "s3_region" {
  description = "Region string required by the S3 API. Use 'us-east-1' for MinIO; use the Hetzner region (e.g. 'eu-central') for Hetzner."
  type        = string
  default     = "us-east-1"
}

variable "s3_access_key" {
  description = "S3 access key ID. Leave empty when using s3_credentials_secret_name."
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_secret_key" {
  description = "S3 secret access key. Leave empty when using s3_credentials_secret_name."
  type        = string
  default     = ""
  sensitive   = true
}

# ── Optional: pre-existing credentials secret ────────────────────────────────
# Use this when you already have a Kubernetes Secret with S3 credentials.
# All three apps (Mimir, Loki, Tempo) will reference the same secret.
# For per-app secrets, pass s3_credentials_secret directly in each module block.

variable "s3_credentials_secret_name" {
  description = "Name of a pre-existing Kubernetes Secret containing S3 credentials. When set, s3_access_key and s3_secret_key are ignored."
  type        = string
  default     = ""
}

variable "s3_credentials_secret_access_key_field" {
  description = "Key within the secret holding the S3 access key ID."
  type        = string
  default     = "access-key"
}

variable "s3_credentials_secret_secret_key_field" {
  description = "Key within the secret holding the S3 secret access key."
  type        = string
  default     = "secret-key"
}

variable "s3_path_style" {
  description = "Enable path-style bucket access. Required for Hetzner, MinIO, Ceph, and most non-AWS S3 services."
  type        = bool
  default     = true
}

variable "s3_insecure" {
  description = "Allow plain HTTP connections. Set true only for internal MinIO without TLS."
  type        = bool
  default     = false
}

# ── Bucket / container names ────────────────────────────────────────────────
# Pre-create these before running terraform apply.

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

# ── Optional ingress ─────────────────────────────────────────────────────────

variable "ingress_domain" {
  description = "Domain for Grafana ingress. Leave empty to disable ingress."
  type        = string
  default     = ""
}

# ── Optional alerting ────────────────────────────────────────────────────────

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
