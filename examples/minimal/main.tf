# Minimal example: Mimir with local-disk storage + kube-prometheus-stack.
# No cloud credentials required — data is stored on the pod's local filesystem.
# Suitable for development and blog-post walkthroughs.
#
# For production deployments with persistent object storage, see:
#   examples/aws  — S3 backend
#   examples/gcp  — GCS backend

module "cert_manager" {
  source       = "../../modules/cert-manager"
  cert_manager = var.cert_manager
}

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
    mimir_tenant_id        = module.mimir.tenant_id
    loki_datasource_url    = module.loki.datasource_url
    tempo_datasource_url   = module.tempo.datasource_url
    grafana_ingress = {
      enabled = true
      host    = "grafana.${var.ingress_domain}"
    }
  })
}

module "loki" {
  source = "../../modules/loki"
  loki = merge(var.loki, {
    # Mimir already created the monitoring namespace; skip re-creation.
    create_namespace = false
    # deployment_mode = "scalable"
  })
}

module "tempo" {
  source = "../../modules/tempo"
  tempo = merge(var.tempo, {
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

output "tempo_datasource_url" {
  description = "Grafana datasource URL for Tempo."
  value       = module.tempo.datasource_url
}

module "otel" {
  source = "../../modules/otel-collector"
  otel = merge(var.otel, {
    create_namespace = false
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    loki_endpoint    = module.loki.datasource_url
  })
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint for app instrumentation."
  value       = module.otel.otlp_grpc_endpoint
}
