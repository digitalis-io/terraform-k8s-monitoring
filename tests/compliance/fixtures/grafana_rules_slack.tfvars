# Fixture — Slack + PagerDuty contact points enabled. Used to verify that the
# credential-bearing contact-points resource is provisioned as a Secret, never a
# ConfigMap. The webhook URL / integration key here are test placeholders.
grafana_rules = {
  namespace = "monitoring"
  slack = {
    enabled     = true
    webhook_url = "https://hooks.slack.example/T000/B000/fixture-placeholder-not-a-secret"
    channel     = "#alerts"
  }
  pagerduty = {
    enabled         = true
    integration_key = "fixture-placeholder-not-a-secret"
  }
}
