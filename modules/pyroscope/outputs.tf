output "namespace" {
  description = "Kubernetes namespace where Pyroscope is deployed."
  value       = var.pyroscope.namespace
}

output "datasource_url" {
  description = "Grafana datasource URL for this Pyroscope instance (port 4040)."
  value       = "http://pyroscope.${var.pyroscope.namespace}.svc.cluster.local:4040"
}

output "push_url" {
  description = "Pyroscope push endpoint for profiling SDKs (port 4040)."
  value       = "http://pyroscope.${var.pyroscope.namespace}.svc.cluster.local:4040"
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.pyroscope.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.pyroscope.version
}
