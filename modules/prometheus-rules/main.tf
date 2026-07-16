locals {
  bundled_rules = {
    for f in fileset("${path.module}/rules", "*.yaml") :
    f => file("${path.module}/rules/${f}")
  }
  all_rules = merge(local.bundled_rules, var.prometheus_rules.extra_rules)

  has_receivers = var.prometheus_rules.slack.enabled || var.prometheus_rules.pagerduty.enabled

  # Pre-compute the severity regex for each receiver based on min_severity.
  slack_severity_regex = {
    "critical" = "critical"
    "warning"  = "critical|warning"
    "info"     = "critical|warning|info"
  }
  pagerduty_severity_regex = {
    "critical" = "critical"
    "warning"  = "critical|warning"
    "info"     = "critical|warning|info"
  }

  # The top-level route always falls back to Alertmanager's built-in "null"
  # receiver, which silently drops alerts. Delivery happens solely via the
  # explicit per-severity child routes below, so an alert that doesn't clear a
  # receiver's min_severity is dropped rather than leaking through a catch-all
  # default (which previously defeated the configured threshold). See #32.
  default_receiver = "null"
}

# Apply each PrometheusRule manifest via kubectl after the Helm release completes.
# terraform_data avoids kubernetes_manifest plan-time CRD validation failure.
resource "terraform_data" "prometheus_rule" {
  for_each = local.all_rules

  # Stored as a map (not a list) so the destroy-time provisioner below can read
  # the namespace/kubeconfig/manifest via self.triggers_replace — destroy-time
  # provisioners cannot reference var.*.
  triggers_replace = {
    release_id      = var.prometheus_rules.prometheus_release_id
    manifest        = each.value
    namespace       = var.prometheus_rules.namespace
    kubeconfig_path = var.prometheus_rules.kubeconfig_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      ${var.prometheus_rules.kubeconfig_path != "" ? "kubectl --kubeconfig=${var.prometheus_rules.kubeconfig_path}" : "kubectl"} apply -n ${var.prometheus_rules.namespace} -f - <<'YAML'
${each.value}
YAML
    EOT
  }

  # Remove the PrometheusRule on destroy so it isn't orphaned on the cluster.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ${self.triggers_replace.kubeconfig_path != "" ? "kubectl --kubeconfig=${self.triggers_replace.kubeconfig_path}" : "kubectl"} delete -n ${self.triggers_replace.namespace} --ignore-not-found=true -f - <<'YAML'
${self.triggers_replace.manifest}
YAML
    EOT
  }
}

# AlertmanagerConfig CRD — routes alerts to Slack and/or PagerDuty.
# Only created when at least one receiver is enabled.
resource "terraform_data" "alertmanager_config" {
  count = local.has_receivers ? 1 : 0

  # Map (not list) so the destroy-time provisioner can read namespace/kubeconfig
  # via self.triggers_replace. Credentials are hashed rather than stored raw —
  # triggers_replace is a plain (non-sensitive) attribute and would otherwise
  # echo the Slack webhook URL / PagerDuty routing key in plan output. The hash
  # still changes when the credential changes, so the config is re-applied.
  triggers_replace = {
    release_id         = var.prometheus_rules.prometheus_release_id
    slack_enabled      = var.prometheus_rules.slack.enabled
    slack_webhook_hash = sha256(var.prometheus_rules.slack.webhook_url)
    slack_channel      = var.prometheus_rules.slack.channel
    slack_severity     = var.prometheus_rules.slack.min_severity
    pagerduty_enabled  = var.prometheus_rules.pagerduty.enabled
    pagerduty_key_hash = sha256(var.prometheus_rules.pagerduty.routing_key)
    pagerduty_severity = var.prometheus_rules.pagerduty.min_severity
    namespace          = var.prometheus_rules.namespace
    kubeconfig_path    = var.prometheus_rules.kubeconfig_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      ${var.prometheus_rules.kubeconfig_path != "" ? "kubectl --kubeconfig=${var.prometheus_rules.kubeconfig_path}" : "kubectl"} apply -n ${var.prometheus_rules.namespace} -f - <<'YAML'
${templatefile("${path.module}/templates/alertmanager-config.yaml.tftpl", {
    slack_enabled        = var.prometheus_rules.slack.enabled
    slack_channel        = var.prometheus_rules.slack.channel
    slack_severity_regex = local.slack_severity_regex[var.prometheus_rules.slack.min_severity]

    pagerduty_enabled        = var.prometheus_rules.pagerduty.enabled
    pagerduty_severity_regex = local.pagerduty_severity_regex[var.prometheus_rules.pagerduty.min_severity]

    default_receiver = local.default_receiver
})}
YAML
    EOT
}

# Remove the AlertmanagerConfig (kind/name fixed as "receivers") on destroy.
provisioner "local-exec" {
  when    = destroy
  command = "${self.triggers_replace.kubeconfig_path != "" ? "kubectl --kubeconfig=${self.triggers_replace.kubeconfig_path}" : "kubectl"} delete alertmanagerconfig receivers -n ${self.triggers_replace.namespace} --ignore-not-found=true"
}

# The AlertmanagerConfig references the Slack/PagerDuty Secrets by name, so they
# must exist before it is applied.
depends_on = [
  terraform_data.prometheus_rule,
  kubernetes_secret.slack,
  kubernetes_secret.pagerduty,
]
}

# Kubernetes Secrets for sensitive receiver credentials.
# AlertmanagerConfig references these by name rather than embedding values.
resource "kubernetes_secret" "slack" {
  count = var.prometheus_rules.slack.enabled ? 1 : 0

  metadata {
    name      = "alertmanager-slack-secret"
    namespace = var.prometheus_rules.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    webhook_url = var.prometheus_rules.slack.webhook_url
  }
}

resource "kubernetes_secret" "pagerduty" {
  count = var.prometheus_rules.pagerduty.enabled ? 1 : 0

  metadata {
    name      = "alertmanager-pagerduty-secret"
    namespace = var.prometheus_rules.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    routing_key = var.prometheus_rules.pagerduty.routing_key
  }
}
