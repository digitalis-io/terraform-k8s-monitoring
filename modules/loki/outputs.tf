output "namespace" {
  description = "Kubernetes namespace where Loki is deployed."
  value       = var.loki.namespace
}

output "datasource_url" {
  description = "Grafana datasource URL for this Loki instance."
  value       = "http://loki.${var.loki.namespace}.svc.cluster.local:3100"
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.loki.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.loki.version
}
