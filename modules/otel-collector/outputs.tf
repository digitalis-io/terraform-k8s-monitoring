output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint for app instrumentation (port 4317)."
  value       = "http://otel-opentelemetry-collector.${var.otel.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "OTLP HTTP endpoint for app instrumentation (port 4318)."
  value       = "http://otel-opentelemetry-collector.${var.otel.namespace}.svc.cluster.local:4318"
}

output "namespace" {
  description = "Kubernetes namespace where the OpenTelemetry Collector is deployed."
  value       = var.otel.namespace
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.otel.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.otel.version
}
