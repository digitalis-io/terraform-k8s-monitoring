# S3-compatible storage example
#
# Deploys the full observability stack using any S3-compatible object store:
#   - Hetzner Object Storage
#   - MinIO (in-cluster or external)
#   - Ceph / RADOS Gateway
#   - Backblaze B2, Wasabi, Cloudflare R2, or any other S3-compatible service
#
# Pre-create all buckets before running terraform apply.
# This module does not create buckets.
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars
#   # edit terraform.tfvars with your values
#   terraform init
#   terraform apply

locals {
  # When a pre-existing secret is named, use it and leave plain-text keys empty.
  # Otherwise plain-text keys are passed and each module creates its own secret automatically.
  use_external_secret = var.s3_credentials_secret_name != ""

  # Shared credentials secret reference — same secret for Mimir, Loki, and Tempo.
  # Pass null when using plain-text keys (modules create per-app secrets in that case).
  s3_credentials_secret = local.use_external_secret ? {
    name             = var.s3_credentials_secret_name
    access_key_field = var.s3_credentials_secret_access_key_field
    secret_key_field = var.s3_credentials_secret_secret_key_field
  } : null

  # Shared S3 config block — applied identically to Mimir, Loki, and Tempo.
  s3_common = {
    backend               = "s3"
    s3_region             = var.s3_region
    s3_endpoint           = var.s3_endpoint
    s3_path_style         = var.s3_path_style
    s3_insecure           = var.s3_insecure
    s3_access_key         = local.use_external_secret ? "" : var.s3_access_key
    s3_secret_key         = local.use_external_secret ? "" : var.s3_secret_key
    s3_credentials_secret = local.s3_credentials_secret
  }
}

module "cert_manager" {
  source = "../../modules/cert-manager"
}

module "mimir" {
  source = "../../modules/mimir"

  mimir = {
    namespace        = "monitoring"
    retention_period = "30d"

    storage = merge(local.s3_common, {
      s3_blocks_bucket       = var.mimir_blocks_bucket
      s3_blocks_prefix       = var.mimir_blocks_prefix
      s3_ruler_bucket        = var.mimir_ruler_bucket
      s3_ruler_prefix        = var.mimir_ruler_prefix
      s3_alertmanager_bucket = var.mimir_alertmanager_bucket
      s3_alertmanager_prefix = var.mimir_alertmanager_prefix
    })
  }
}

module "loki" {
  source = "../../modules/loki"

  loki = {
    namespace        = "monitoring"
    create_namespace = false

    storage = merge(local.s3_common, {
      s3_chunks_bucket = var.loki_chunks_bucket
      s3_ruler_bucket  = var.loki_ruler_bucket
    })
  }
}

module "tempo" {
  source = "../../modules/tempo"

  tempo = {
    namespace        = "monitoring"
    create_namespace = false

    storage = merge(local.s3_common, {
      s3_bucket = var.tempo_bucket
    })
  }
}

module "pyroscope" {
  source = "../../modules/pyroscope"

  pyroscope = {
    namespace        = "monitoring"
    create_namespace = false

    storage = {
      backend               = var.pyroscope_bucket != "" ? "s3" : "local"
      s3_bucket             = var.pyroscope_bucket
      s3_region             = var.s3_region
      s3_endpoint           = var.s3_endpoint
      s3_path_style         = var.s3_path_style
      s3_insecure           = var.s3_insecure
      s3_access_key         = local.use_external_secret ? "" : var.s3_access_key
      s3_secret_key         = local.use_external_secret ? "" : var.s3_secret_key
      s3_credentials_secret = local.s3_credentials_secret
    }
  }
}

module "prometheus" {
  source = "../../modules/prometheus"

  prometheus = {
    namespace        = "monitoring"
    create_namespace = false

    mimir_remote_write_url   = module.mimir.remote_write_endpoint
    mimir_datasource_url     = module.mimir.query_frontend_endpoint
    mimir_tenant_id          = module.mimir.tenant_id
    loki_datasource_url      = module.loki.datasource_url
    tempo_datasource_url     = module.tempo.datasource_url
    pyroscope_datasource_url = module.pyroscope.datasource_url

    grafana_ingress = var.ingress_domain != "" ? {
      enabled    = true
      host       = "grafana.${var.ingress_domain}"
      class_name = "traefik"
    } : {}
  }
}

module "otel" {
  source = "../../modules/otel-collector"

  otel = {
    namespace        = "monitoring"
    create_namespace = false
    mode             = "daemonset"
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    loki_endpoint    = module.loki.datasource_url
  }
}

module "prometheus_rules" {
  source = "../../modules/prometheus-rules"

  prometheus_rules = {
    namespace             = "monitoring"
    prometheus_release_id = module.prometheus.helm_release_id
    kubeconfig_path       = var.kubeconfig_path

    slack = var.slack_webhook_url != "" ? {
      enabled      = true
      webhook_url  = var.slack_webhook_url
      channel      = var.slack_channel
      min_severity = "warning"
    } : {}
  }
}

module "grafana_rules" {
  source = "../../modules/grafana-rules"

  grafana_rules = {
    namespace = "monitoring"

    slack = var.slack_webhook_url != "" ? {
      enabled      = true
      webhook_url  = var.slack_webhook_url
      channel      = var.slack_channel
      min_severity = "warning"
    } : {}
  }
}

# ── Outputs ──────────────────────────────────────────────────────────────────

output "grafana_url" {
  description = "In-cluster Grafana URL."
  value       = module.prometheus.grafana_service
}

output "remote_write_endpoint" {
  description = "Prometheus remote_write URL for external scrapers."
  value       = module.mimir.remote_write_endpoint
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint for app instrumentation (traces, metrics, logs)."
  value       = module.otel.otlp_grpc_endpoint
}

output "loki_endpoint" {
  description = "Loki push endpoint for external log shippers."
  value       = module.loki.datasource_url
}

output "pyroscope_push_url" {
  description = "Pyroscope push endpoint for profiling SDKs."
  value       = module.pyroscope.push_url
}
