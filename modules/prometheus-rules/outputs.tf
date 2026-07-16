output "namespace" {
  description = "Kubernetes namespace where the PrometheusRules and AlertmanagerConfig are applied."
  value       = var.prometheus_rules.namespace
}

output "rule_names" {
  description = "Filenames (keys) of the PrometheusRule manifests applied by the module."
  value       = keys(local.all_rules)
}

output "alertmanager_config_applied" {
  description = "Whether an AlertmanagerConfig was applied (true when at least one receiver is enabled)."
  value       = local.has_receivers
}
