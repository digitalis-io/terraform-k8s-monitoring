# Tests that modules/mimir deploys the mimir-distributed Helm chart from the
# Grafana chart repository into the configured namespace, planned from the
# mimir_defaults.tfvars fixture.
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).

Feature: Mimir Helm release is configured correctly

  Background:
    Given I have helm_release defined

  Scenario: Release uses the mimir-distributed chart
    Then its chart must be "mimir-distributed"

  Scenario: Release pulls from the Grafana chart repository
    Then its repository must be "https://grafana.github.io/helm-charts"

  Scenario: Release is deployed into the monitoring namespace
    Then its namespace must be "monitoring"
