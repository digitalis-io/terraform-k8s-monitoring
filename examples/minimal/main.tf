# Minimal example: Mimir with local-disk storage.
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

output "remote_write_endpoint" {
  description = "Prometheus remote_write URL."
  value       = module.mimir.remote_write_endpoint
}

output "query_frontend_endpoint" {
  description = "Grafana datasource URL."
  value       = module.mimir.query_frontend_endpoint
}
