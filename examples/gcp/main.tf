# GCP GCS storage example with Workload Identity
#
# Deploys the full observability stack using Google Cloud Storage for durable storage.
# Each component (Mimir, Loki, Tempo) uses a dedicated Google Service Account via
# GKE Workload Identity for secure, keyless access to GCS — no static credentials required.
#
# Prerequisites:
#   1. Pre-create all GCS buckets before running terraform apply.
#      This module does not create buckets.
#   2. Pre-create Google Service Accounts with Storage Object Admin permissions on their
#      respective buckets, and bind them to Kubernetes service accounts via Workload Identity:
#
#        gcloud iam service-accounts add-iam-policy-binding \
#          mimir@PROJECT.iam.gserviceaccount.com \
#          --role roles/iam.workloadIdentityUser \
#          --member "serviceAccount:PROJECT.svc.id.goog[monitoring/mimir]"
#
#      See: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars
#   # edit terraform.tfvars with your values
#   terraform init
#   terraform apply

module "cert_manager" {
  source = "../../modules/cert-manager"
}

module "mimir" {
  source = "../../modules/mimir"

  mimir = {
    namespace        = "monitoring"
    retention_period = "30d"

    storage = {
      backend = "gcs"

      gcs_blocks_bucket       = var.mimir_blocks_bucket
      gcs_ruler_bucket        = var.mimir_ruler_bucket
      gcs_alertmanager_bucket = var.mimir_alertmanager_bucket

      # Workload Identity provides credentials via the pod identity — no key file needed.
      gcs_service_account_key = ""
    }

    service_account_annotations = {
      "iam.gke.io/gcp-service-account" = var.mimir_gsa_email
    }
  }
}

module "loki" {
  source = "../../modules/loki"

  loki = {
    namespace        = "monitoring"
    create_namespace = false

    storage = {
      backend = "gcs"

      gcs_chunks_bucket = var.loki_chunks_bucket
      gcs_ruler_bucket  = var.loki_ruler_bucket

      # Workload Identity provides credentials via the pod identity — no key file needed.
      gcs_service_account_key = ""
    }

    service_account_annotations = {
      "iam.gke.io/gcp-service-account" = var.loki_gsa_email
    }
  }
}

module "tempo" {
  source = "../../modules/tempo"

  tempo = {
    namespace        = "monitoring"
    create_namespace = false

    storage = {
      backend = "gcs"

      gcs_bucket = var.tempo_bucket

      # Workload Identity provides credentials via the pod identity — no key file needed.
      gcs_service_account_key = ""
    }

    service_account_annotations = {
      "iam.gke.io/gcp-service-account" = var.tempo_gsa_email
    }
  }
}

module "prometheus" {
  source = "../../modules/prometheus"

  prometheus = {
    namespace        = "monitoring"
    create_namespace = false

    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id
    loki_datasource_url    = module.loki.datasource_url
    tempo_datasource_url   = module.tempo.datasource_url

    grafana_ingress = var.ingress_domain != "" ? {
      enabled    = true
      host       = "grafana.${var.ingress_domain}"
      class_name = var.ingress_class_name
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

    pagerduty = var.pagerduty_routing_key != "" ? {
      enabled     = true
      routing_key = var.pagerduty_routing_key
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

    pagerduty = var.pagerduty_routing_key != "" ? {
      enabled         = true
      integration_key = var.pagerduty_routing_key
    } : {}
  }
}

# -- Outputs -------------------------------------------------------------------

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
