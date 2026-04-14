variable "grafana_rules" {
  description = "Grafana-managed alert rules and notification contact points."
  type = object({
    # Namespace must match where kube-prometheus-stack (Grafana) is deployed.
    namespace = optional(string, "monitoring")

    # Additional alert rule YAML files supplied by the caller.
    # key = filename (e.g. "my-app.yaml"), value = YAML content via file().
    # Merged with the bundled rules in modules/grafana-rules/rules/.
    extra_rules = optional(map(string), {})

    # Slack contact point.
    slack = optional(object({
      enabled     = optional(bool, false)
      webhook_url = optional(string, "")
      channel     = optional(string, "#alerts")
      # Minimum severity label value to match. Values: "critical" | "warning" | "info"
      min_severity = optional(string, "warning")
    }), {})

    # PagerDuty contact point.
    pagerduty = optional(object({
      enabled         = optional(bool, false)
      integration_key = optional(string, "")
      min_severity    = optional(string, "critical")
    }), {})

    # Generic webhook contact point (e.g. for OpsGenie, VictorOps, custom receivers).
    webhook = optional(object({
      enabled      = optional(bool, false)
      url          = optional(string, "")
      http_method  = optional(string, "POST")
      min_severity = optional(string, "warning")
    }), {})

    # Email contact point.
    email = optional(object({
      enabled      = optional(bool, false)
      addresses    = optional(list(string), [])
      min_severity = optional(string, "critical")
    }), {})
  })

  validation {
    condition     = !var.grafana_rules.slack.enabled || var.grafana_rules.slack.webhook_url != ""
    error_message = "slack.webhook_url is required when slack.enabled is true."
  }

  validation {
    condition     = !var.grafana_rules.pagerduty.enabled || var.grafana_rules.pagerduty.integration_key != ""
    error_message = "pagerduty.integration_key is required when pagerduty.enabled is true."
  }

  validation {
    condition     = !var.grafana_rules.webhook.enabled || var.grafana_rules.webhook.url != ""
    error_message = "webhook.url is required when webhook.enabled is true."
  }

  validation {
    condition     = !var.grafana_rules.email.enabled || length(var.grafana_rules.email.addresses) > 0
    error_message = "email.addresses must not be empty when email.enabled is true."
  }
}
