output "namespace" {
  description = "Kubernetes namespace where Mimir is deployed."
  value       = kubernetes_namespace.mimir.metadata[0].name
}

output "remote_write_endpoint" {
  description = "Prometheus remote_write URL for this Mimir instance."
  value       = "http://mimir-nginx.${var.mimir.namespace}.svc.cluster.local/api/v1/push"
}

output "query_frontend_endpoint" {
  description = "Grafana datasource URL (Prometheus-compatible) for this Mimir instance."
  value       = "http://mimir-query-frontend.${var.mimir.namespace}.svc.cluster.local:8080/prometheus"
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.mimir.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.mimir.version
}
