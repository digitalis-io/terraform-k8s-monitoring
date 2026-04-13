output "namespace" {
  description = "Kubernetes namespace where kube-prometheus-stack is deployed."
  value       = kubernetes_namespace.prometheus.metadata[0].name
}

output "grafana_service" {
  description = "In-cluster URL for the Grafana service."
  value       = "http://prometheus-grafana.${var.prometheus.namespace}.svc.cluster.local"
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.prometheus.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.prometheus.version
}
