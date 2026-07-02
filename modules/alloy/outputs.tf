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

output "helm_release_id" {
  description = "Helm release ID — used as a dependency anchor for other modules."
  value       = helm_release.alloy.id
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint exposed by Alloy (port 4317). Wire to instrumented applications."
  value       = "http://${helm_release.alloy.name}.${var.alloy.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "OTLP HTTP endpoint exposed by Alloy (port 4318). Wire to instrumented applications."
  value       = "http://${helm_release.alloy.name}.${var.alloy.namespace}.svc.cluster.local:4318"
}

output "faro_receiver_http_endpoint" {
  description = "In-cluster HTTP endpoint for the Faro receiver (only meaningful when faro_receiver.enabled = true). Wire this into the Faro Web SDK baseUrl for applications running inside the cluster."
  value       = local.faro_enabled ? "http://${helm_release.alloy.name}.${var.alloy.namespace}.svc.cluster.local:${local.faro_port}/collect" : ""
}

output "faro_receiver_public_url" {
  description = "Public HTTP(S) URL for the Faro receiver — only set when faro_receiver.enabled and ingress.enabled are both true. Use for browser-based applications running outside the cluster."
  value       = local.faro_enabled && try(var.alloy.ingress.enabled, false) ? format("%s://%s/collect", try(var.alloy.ingress.tls_secret, "") != "" ? "https" : "http", var.alloy.ingress.host) : ""
}
