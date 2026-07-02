# Tests that the helm_release resource targets the correct Grafana chart
# repository and chart name, and does not manage namespace creation itself
# (the kubernetes_namespace resource handles that so labels are controlled).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe.
#
# Note: 'it must contain X' replaces the stash with the raw value; chaining
# 'its X must be Y' after it fails in terraform-compliance 1.15.1 because the
# string entity hits the str/int/bool branch which always errors.
# Use 'its X must be Y' directly against the resource stash instead.

Feature: Alloy Helm release targets the correct chart

  Background:
    Given I have helm_release defined

  Scenario: Release uses the Grafana Helm repository
    Then its repository must be "https://grafana.github.io/helm-charts"

  Scenario: Release uses the alloy chart
    Then its chart must be "alloy"

  Scenario: Release is named alloy
    Then its name must be "alloy"

  Scenario: Release does not create the namespace itself
    # The kubernetes_namespace resource controls namespace labels;
    # helm_release must not create it independently.
    Then its create_namespace must be false

  Scenario: Release targets the monitoring namespace by default
    Then its namespace must be "monitoring"
