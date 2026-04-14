variable "prometheus_rules" {
  description = "Prometheus alert rules and Alertmanager receiver configuration."
  type = object({
    # Namespace must match where kube-prometheus-stack is deployed.
    namespace = optional(string, "monitoring")

    # Path to the kubeconfig file used by kubectl in local-exec provisioners.
    # Defaults to ~/.kube/config. Set explicitly to avoid KUBECONFIG env var interference.
    kubeconfig_path = optional(string, "")

    # Output from module.prometheus.helm_release_id — enforces apply order so
    # PrometheusRule and AlertmanagerConfig CRDs exist before kubectl apply runs.
    prometheus_release_id = string

    # Additional alert rule YAML files supplied by the caller.
    # key = filename (e.g. "my-app.yaml"), value = YAML content via file().
    # Merged with the bundled rules in modules/prometheus-rules/rules/.
    # Example: { "my-app.yaml" = file("${path.module}/rules/my-app.yaml") }
    extra_rules = optional(map(string), {})

    # Slack receiver — leave enabled=false (default) to skip.
    slack = optional(object({
      enabled     = optional(bool, false)
      webhook_url = optional(string, "")
      channel     = optional(string, "#alerts")
      # Minimum severity to route to Slack. Alerts below this are suppressed.
      # Values: "critical" | "warning" | "info"
      min_severity = optional(string, "warning")
    }), {})

    # PagerDuty receiver — leave enabled=false (default) to skip.
    pagerduty = optional(object({
      enabled     = optional(bool, false)
      routing_key = optional(string, "")
      # Only critical alerts go to PagerDuty by default.
      min_severity = optional(string, "critical")
    }), {})
  })

  validation {
    condition     = !var.prometheus_rules.slack.enabled || var.prometheus_rules.slack.webhook_url != ""
    error_message = "slack.webhook_url is required when slack.enabled is true."
  }

  validation {
    condition     = !var.prometheus_rules.pagerduty.enabled || var.prometheus_rules.pagerduty.routing_key != ""
    error_message = "pagerduty.routing_key is required when pagerduty.enabled is true."
  }
}
