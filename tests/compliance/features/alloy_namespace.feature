# Tests that modules/alloy creates the Kubernetes namespace with the required
# managed-by and component labels when create_namespace = true (the default).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe (read-only plan assertions).

Feature: Alloy namespace is created with required labels

  Background:
    Given I have kubernetes_namespace defined

  Scenario: Namespace carries the managed-by label
    Then it must contain metadata
    And its metadata must contain labels
    And its metadata.labels must contain "app.kubernetes.io/managed-by"
    And its metadata.labels.app\.kubernetes\.io/managed-by must be "terraform"

  Scenario: Namespace carries the component label
    Then it must contain metadata
    And its metadata must contain labels
    And its metadata.labels must contain "app.kubernetes.io/component"
    And its metadata.labels.app\.kubernetes\.io/component must be "monitoring"
