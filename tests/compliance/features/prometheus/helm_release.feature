# Tests that the prometheus module's helm_release targets the correct
# kube-prometheus-stack chart/repository and stays intact even when every
# metrics component is toggled off (the Grafana-only configuration).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe.
#
# Note: 'its X must be Y' is asserted directly against the resource stash;
# see the alloy feature for why chaining after 'it must contain' is avoided in
# terraform-compliance 1.15.1.

Feature: Prometheus Helm release targets kube-prometheus-stack

  Background:
    Given I have helm_release defined

  Scenario: Release uses the prometheus-community Helm repository
    Then its repository must be "https://prometheus-community.github.io/helm-charts"

  Scenario: Release uses the kube-prometheus-stack chart
    Then its chart must be "kube-prometheus-stack"

  Scenario: Release is named prometheus
    Then its name must be "prometheus"

  Scenario: Release does not create the namespace itself
    # The kubernetes_namespace resource controls namespace labels;
    # helm_release must not create it independently.
    Then its create_namespace must be false

  Scenario: Release targets the monitoring namespace by default
    Then its namespace must be "monitoring"
