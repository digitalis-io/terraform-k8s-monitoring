output "namespace" {
  description = "Kubernetes namespace where Tempo is deployed."
  value       = var.tempo.namespace
}

output "datasource_url" {
  description = "Grafana datasource URL for this Tempo instance."
  value       = "http://tempo-query-frontend.${var.tempo.namespace}.svc.cluster.local:3100"
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.tempo.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.tempo.version
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint for sending traces to Tempo (port 4317)."
  value       = "http://tempo-distributor.${var.tempo.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "OTLP HTTP endpoint for sending traces to Tempo (port 4318)."
  value       = "http://tempo-distributor.${var.tempo.namespace}.svc.cluster.local:4318"
}
