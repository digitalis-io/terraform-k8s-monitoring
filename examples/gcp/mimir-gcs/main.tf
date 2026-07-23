# GCP Mimir + Grafana — Google Cloud Storage backend
#
# Deploys Grafana Mimir (distributed) with GCS durable storage and a Grafana
# datasource on GKE using Workload Identity (keyless auth). Unlike the full-stack
# example one directory up (examples/gcp), this is a metrics-only slice: Mimir for
# storage/query and Grafana for visualisation, with no local Prometheus, Loki, or
# Tempo. An external Prometheus (or the OTel Collector) remote-writes into Mimir.
#
# Prerequisites:
#   1. Pre-create all GCS buckets before running terraform apply.
#      This module does not create buckets.
#   2. Pre-create a Google Service Account with Storage Object Admin permissions,
#      and bind it to the Kubernetes service account via Workload Identity:
#
#        gcloud iam service-accounts create mimir \
#          --display-name="Mimir storage access"
#
#        gsutil iam ch serviceAccount:mimir@PROJECT.iam.gserviceaccount.com:objectAdmin \
#          gs://PROJECT-mimir-blocks gs://PROJECT-mimir-ruler gs://PROJECT-mimir-alertmanager
#
#        gcloud iam service-accounts add-iam-policy-binding \
#          mimir@PROJECT.iam.gserviceaccount.com \
#          --role roles/iam.workloadIdentityUser \
#          --member "serviceAccount:PROJECT.svc.id.goog[monitoring/mimir]"
#
#   3. Ensure your GKE cluster has Workload Identity enabled:
#
#        gcloud container clusters update <cluster> \
#          --zone <zone> --workload-pool=PROJECT.svc.id.goog
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars
#   # edit terraform.tfvars with your values
#   terraform init
#   terraform apply

# -- cert-manager (ingress TLS) -----------------------------------------------
#
# Issues public TLS certificates via ACME (Let's Encrypt) with an HTTP-01 solver
# on the GCE ingress class. The issuer is named "letsencrypt-prod" to match the
# default cert-manager.io/cluster-issuer annotation used by the Mimir and Grafana
# ingresses below.

module "cert_manager" {
  source = "../../../modules/cert-manager"

  cert_manager = {
    kubeconfig_path     = var.kubeconfig_path
    cluster_issuer_name = "letsencrypt-prod"

    issuer = {
      type = "acme"
      acme = {
        email                = var.acme_email
        solver_ingress_class = "gce"
      }
    }
  }
}

# -- Mimir (GCS backend) ------------------------------------------------------

module "mimir" {
  source = "../../../modules/mimir"

  mimir = {
    namespace        = var.namespace
    retention_period = "30d"
    replicas         = 1

    ingress_enabled    = true
    ingress_host       = "mimir.${var.ingress_domain}"
    ingress_class_name = "gce"
    ingress_tls_secret = "mimir-tls"
    # ingress_annotations defaults to cert-manager.io/cluster-issuer=letsencrypt-prod,
    # which matches the ClusterIssuer created by module.cert_manager above.

    storage = {
      backend = "gcs"

      gcs_blocks_bucket       = var.mimir_blocks_bucket
      gcs_ruler_bucket        = var.mimir_ruler_bucket
      gcs_alertmanager_bucket = var.mimir_alertmanager_bucket

      # Keyless via GKE Workload Identity — no GCS key file needed.
      gcs_service_account_key = ""
    }

    service_account_annotations = {
      "iam.gke.io/gcp-service-account" = var.mimir_gsa_email
    }
  }
}

# -- Grafana (via kube-prometheus-stack, Grafana-only) ------------------------
#
# Every kube-prometheus-stack component except Grafana is disabled — this stack
# stores and queries metrics in Mimir, not a local Prometheus.

module "prometheus" {
  source = "../../../modules/prometheus"

  prometheus = {
    namespace            = var.namespace
    create_namespace     = false
    grafana_enabled      = true
    prometheus_enabled   = false # no local Prometheus; remote_write to Mimir
    alertmanager_enabled = false

    grafana_ingress = {
      enabled    = true
      host       = "grafana.${var.ingress_domain}"
      class_name = "gce"
      tls_secret = "grafana-tls"
      annotations = {
        "cert-manager.io/cluster-issuer" = module.cert_manager.cluster_issuer_name
      }
    }

    prometheus_ingress   = { enabled = false }
    alertmanager_ingress = { enabled = false }

    # Wire Grafana to Mimir as the datasource + remote_write target.
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id
  }
}

# -- Outputs -------------------------------------------------------------------

output "grafana_url" {
  description = "External URL for the Grafana dashboard."
  value       = "https://grafana.${var.ingress_domain}"
}

output "mimir_url" {
  description = "External URL for the Mimir API (nginx gateway)."
  value       = "https://mimir.${var.ingress_domain}"
}

output "mimir_remote_write_endpoint" {
  description = "In-cluster remote_write URL for external Prometheus."
  value       = module.mimir.remote_write_endpoint
}

output "mimir_query_frontend_endpoint" {
  description = "In-cluster query frontend URL for the Grafana datasource."
  value       = module.mimir.query_frontend_endpoint
}

output "mimir_tenant_id" {
  description = "Mimir tenant ID (X-Scope-OrgID header)."
  value       = module.mimir.tenant_id
}
