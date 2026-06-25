# Tests that modules/alloy creates the Kubernetes namespace with the required
# managed-by and component labels when create_namespace = true (the default).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe (read-only plan assertions).
#
# Note: terraform-compliance only supports 'it must contain <attr>' and
# 'its <attr> must be <value>' for scalar checks. Labels with dots in key
# names are not traversable via the step DSL; label values are verified by
# the terratest suite instead.

Feature: Alloy namespace is created with required labels

  Background:
    Given I have kubernetes_namespace defined

  Scenario: Namespace is named monitoring
    Then it must contain metadata
    And its metadata.name must be "monitoring"

  Scenario: Namespace has labels block defined
    Then it must contain metadata
    And its metadata.labels must exist
