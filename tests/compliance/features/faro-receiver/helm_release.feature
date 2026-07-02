# Tests that the helm_release resource targets the correct Grafana chart
# repository and chart name, and does not manage namespace creation itself
# (the kubernetes_namespace resource handles that so labels are controlled).
#
# Note: the Faro receiver is deployed via the grafana/alloy chart configured
# with Alloy's faro.receiver component — Grafana does not publish a standalone
# "faro" Helm chart.
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe.

Feature: Faro receiver Helm release targets the correct chart

  Background:
    Given I have helm_release defined

  Scenario: Release uses the Grafana Helm repository
    Then its repository must be "https://grafana.github.io/helm-charts"

  Scenario: Release uses the alloy chart
    Then its chart must be "alloy"

  Scenario: Release is named faro-receiver
    Then its name must be "faro-receiver"

  Scenario: Release does not create the namespace itself
    Then its create_namespace must be false

  Scenario: Release targets the monitoring namespace by default
    Then its namespace must be "monitoring"
