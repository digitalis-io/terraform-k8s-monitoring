# Tests that the helm_release resource targets the correct Grafana chart
# repository and chart name, and does not manage namespace creation itself
# (the kubernetes_namespace resource handles that so labels are controlled).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe.

Feature: Alloy Helm release targets the correct chart

  Background:
    Given I have helm_release defined

  Scenario: Release uses the Grafana Helm repository
    Then it must contain repository
    And its repository must be "https://grafana.github.io/helm-charts"

  Scenario: Release uses the alloy chart
    Then it must contain chart
    And its chart must be "alloy"

  Scenario: Release is named alloy
    Then it must contain name
    And its name must be "alloy"

  Scenario: Release does not create the namespace itself
    # The kubernetes_namespace resource controls namespace labels;
    # helm_release must not create it independently.
    Then it must contain create_namespace
    And its create_namespace must be false

  Scenario: Release targets the monitoring namespace by default
    Then it must contain namespace
    And its namespace must be "monitoring"
