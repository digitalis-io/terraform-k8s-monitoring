# Minimal example: Mimir with local-disk storage + kube-prometheus-stack.
# No cloud credentials required — data is stored on the pod's local filesystem.
# Suitable for development and blog-post walkthroughs.
#
# For production deployments with persistent object storage, see:
#   examples/aws  — S3 backend
#   examples/gcp  — GCS backend

module "mimir" {
  source = "../../modules/mimir"
  mimir  = var.mimir
}

module "prometheus" {
  source = "../../modules/prometheus"
  prometheus = merge(var.prometheus, {
    # Mimir already created the monitoring namespace; skip re-creation.
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
  })
}

module "loki" {
  source = "../../modules/loki"
  loki = merge(var.loki, {
    # Mimir already created the monitoring namespace; skip re-creation.
    create_namespace = false
  })
}

output "remote_write_endpoint" {
  description = "Prometheus remote_write URL."
  value       = module.mimir.remote_write_endpoint
}

output "query_frontend_endpoint" {
  description = "Grafana datasource URL."
  value       = module.mimir.query_frontend_endpoint
}

output "grafana_service" {
  description = "In-cluster Grafana service URL."
  value       = module.prometheus.grafana_service
}

output "loki_datasource_url" {
  description = "Grafana datasource URL for Loki."
  value       = module.loki.datasource_url
}
