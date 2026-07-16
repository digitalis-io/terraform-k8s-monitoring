output "namespace" {
  description = "Kubernetes namespace where the alert rules and contact points are provisioned."
  value       = var.grafana_rules.namespace
}

output "rule_configmap_names" {
  description = "Names of the ConfigMaps holding the provisioned Grafana alert rules (one per rule YAML)."
  value       = [for cm in kubernetes_config_map.grafana_rule : cm.metadata[0].name]
}

output "contact_points_secret_name" {
  description = "Name of the Secret holding the contact points and notification policy, or null when no channel is enabled."
  value       = local.has_contact_points ? kubernetes_secret.grafana_contact_points[0].metadata[0].name : null
}
