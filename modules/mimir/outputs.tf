output "namespace" {
  description = "Kubernetes namespace where Mimir is deployed."
  value       = var.mimir.namespace
}

output "remote_write_endpoint" {
  description = "Prometheus remote_write URL for this Mimir instance."
  # Chart 6.x replaced the standalone `nginx` proxy with the `gateway` component,
  # so the write path is served by the `mimir-gateway` service (was `mimir-nginx`).
  value = "http://mimir-gateway.${var.mimir.namespace}.svc.cluster.local/api/v1/push"
}

output "query_frontend_endpoint" {
  description = "Grafana datasource URL (Prometheus-compatible) for this Mimir instance."
  value       = "http://mimir-query-frontend.${var.mimir.namespace}.svc.cluster.local:8080/prometheus"
}

output "tenant_id" {
  description = "Mimir tenant ID. Pass as X-Scope-OrgID header in remote_write and Grafana datasource config."
  value       = var.mimir.tenant_id
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.mimir.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.mimir.version
}
