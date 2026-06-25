output "namespace" {
  description = "Kubernetes namespace where Alloy is deployed."
  value       = var.alloy.namespace
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.alloy.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.alloy.version
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint exposed by Alloy (port 4317). Wire to instrumented applications."
  value       = "http://alloy.${var.alloy.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "OTLP HTTP endpoint exposed by Alloy (port 4318). Wire to instrumented applications."
  value       = "http://alloy.${var.alloy.namespace}.svc.cluster.local:4318"
}
