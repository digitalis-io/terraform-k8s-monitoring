output "namespace" {
  description = "Kubernetes namespace where cert-manager is deployed."
  value       = var.cert_manager.namespace
}

output "cluster_issuer_name" {
  description = "Name of the self-signed ClusterIssuer. Use as cert-manager.io/cluster-issuer annotation value."
  value       = var.cert_manager.cluster_issuer_name
}

output "helm_release_name" {
  description = "Name of the Helm release."
  value       = helm_release.cert_manager.name
}

output "helm_release_version" {
  description = "Deployed chart version."
  value       = helm_release.cert_manager.version
}
