variable "kubeconfig_path" {
  description = "Absolute path to the kubeconfig file. Tilde (~) is not expanded — use $HOME or a full path."
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace for the monitoring stack."
  type        = string
  default     = "monitoring"
}

# -- Ingress -------------------------------------------------------------------

variable "ingress_domain" {
  description = "Base domain for Mimir + Grafana ingress, e.g. monitoring.example.com — Mimir at mimir.<domain>, Grafana at grafana.<domain>."
  type        = string
}

variable "acme_email" {
  description = "Contact email for ACME (Let's Encrypt) certificate registration."
  type        = string
}

# -- GCP Workload Identity -----------------------------------------------------

variable "mimir_gsa_email" {
  description = "Google Service Account email for Mimir (Workload Identity). Must have Storage Object Admin on the Mimir GCS buckets."
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
