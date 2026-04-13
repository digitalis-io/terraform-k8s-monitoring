locals {
  bundled_rules = {
    for f in fileset("${path.module}/rules", "*.yaml") :
    f => file("${path.module}/rules/${f}")
  }
  all_rules = merge(local.bundled_rules, var.grafana_rules.extra_rules)

  has_contact_points = (
    var.grafana_rules.slack.enabled ||
    var.grafana_rules.pagerduty.enabled ||
    var.grafana_rules.webhook.enabled ||
    var.grafana_rules.email.enabled
  )

  severity_regex = {
    "critical" = "critical"
    "warning"  = "critical|warning"
    "info"     = "critical|warning|info"
  }
}

# One ConfigMap per alert rule YAML — bundled files merged with caller-supplied extra_rules.
# The Grafana sidecar (alerts) watches for the grafana_alert label and provisions them.
resource "kubernetes_config_map" "grafana_rule" {
  for_each = local.all_rules

  metadata {
    name      = "grafana-rule-${trimsuffix(each.key, ".yaml")}"
    namespace = var.grafana_rules.namespace

    labels = {
      grafana_alert                  = "1"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    "${each.key}" = each.value
  }
}

# Contact points + notification policy in a single ConfigMap.
# Grafana's alerting provisioning directory supports all resource types in one file.
resource "kubernetes_config_map" "grafana_contact_points" {
  count = local.has_contact_points ? 1 : 0

  metadata {
    name      = "grafana-contact-points"
    namespace = var.grafana_rules.namespace

    labels = {
      grafana_alert                  = "1"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    "contact-points.yaml" = templatefile("${path.module}/templates/contact-points.yaml.tftpl", {
      slack_enabled     = var.grafana_rules.slack.enabled
      slack_webhook_url = var.grafana_rules.slack.webhook_url
      slack_channel     = var.grafana_rules.slack.channel

      pagerduty_enabled         = var.grafana_rules.pagerduty.enabled
      pagerduty_integration_key = var.grafana_rules.pagerduty.integration_key

      webhook_enabled     = var.grafana_rules.webhook.enabled
      webhook_url         = var.grafana_rules.webhook.url
      webhook_http_method = var.grafana_rules.webhook.http_method

      email_enabled   = var.grafana_rules.email.enabled
      email_addresses = join(";", var.grafana_rules.email.addresses)
    })

    "notification-policy.yaml" = templatefile("${path.module}/templates/notification-policy.yaml.tftpl", {
      slack_enabled  = var.grafana_rules.slack.enabled
      slack_severity = local.severity_regex[var.grafana_rules.slack.min_severity]

      pagerduty_enabled  = var.grafana_rules.pagerduty.enabled
      pagerduty_severity = local.severity_regex[var.grafana_rules.pagerduty.min_severity]

      webhook_enabled  = var.grafana_rules.webhook.enabled
      webhook_severity = local.severity_regex[var.grafana_rules.webhook.min_severity]

      email_enabled  = var.grafana_rules.email.enabled
      email_severity = local.severity_regex[var.grafana_rules.email.min_severity]
    })
  }
}
