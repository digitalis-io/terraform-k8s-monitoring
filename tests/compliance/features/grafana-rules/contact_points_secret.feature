# Tests that modules/grafana-rules provisions its contact points (which embed the
# Slack webhook URL and PagerDuty integration key) as a Kubernetes Secret rather
# than a ConfigMap, planned from the grafana_rules_slack.tfvars fixture.
#
# ConfigMaps are stored in plaintext with weaker RBAC than Secrets; credentials
# must never live in one.

Feature: Grafana contact-point credentials are stored in a Secret

  Scenario: A Secret carries the contact points
    Given I have kubernetes_secret defined
    Then it must contain metadata
    And its name must be "grafana-contact-points"

  Scenario: The contact-points Secret is Opaque
    Given I have kubernetes_secret defined
    Then its type must be "Opaque"
