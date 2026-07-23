output "namespace" {
  description = "Kubernetes namespace where Tempo is deployed."
  value       = var.tempo.namespace
}

output "datasource_url" {
  description = "Grafana datasource URL for this Tempo instance."
  # tempo-distributed's query-frontend HTTP API listens on 3200 (server.http_
  # listen_port default); the Service exposes 3200/TCP. 3100 (Loki's port) is
  # nothing here -> Grafana's datasource echo dial-timeouts on the ClusterIP.
  value = "http://tempo-query-frontend.${var.tempo.namespace}.svc.cluster.local:3200"
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
