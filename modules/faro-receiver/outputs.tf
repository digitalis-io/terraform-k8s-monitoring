output "namespace" {
  description = "Kubernetes namespace where the Faro receiver is deployed."
  value       = var.faro_receiver.namespace
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.faro_receiver.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.faro_receiver.version
}

output "helm_release_id" {
  description = "Helm release ID — used as a dependency anchor for other modules."
  value       = helm_release.faro_receiver.id
}

output "service_name" {
  description = "Kubernetes Service name for the Faro receiver."
  value       = "faro-receiver"
}

output "receiver_http_endpoint" {
  description = "In-cluster HTTP endpoint for the Faro receiver. Wire this into the Faro Web SDK baseUrl for applications running inside the cluster."
  value       = "http://faro-receiver.${var.faro_receiver.namespace}.svc.cluster.local:${var.faro_receiver.port}/collect"
}

output "receiver_public_url" {
  description = "Public HTTP(S) URL for the Faro receiver — only set when ingress is enabled. Use for browser-based applications running outside the cluster."
  value       = try(var.faro_receiver.ingress.enabled, false) ? format("%s://%s/collect", try(var.faro_receiver.ingress.tls_secret, "") != "" ? "https" : "http", var.faro_receiver.ingress.host) : ""
}
