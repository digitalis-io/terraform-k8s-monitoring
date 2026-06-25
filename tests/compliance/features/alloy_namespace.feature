# Tests that modules/alloy creates the Kubernetes namespace with the correct
# name when create_namespace = true (the default).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe (read-only plan assertions).
#
# Note: terraform-compliance only supports 'it must contain <attr>' and
# 'its <attr> must be <value>'. Labels with dot-containing key names are
# not traversable via the step DSL; label value assertions live in the
# terratest suite (alloy_test.go) instead.

Feature: Alloy namespace is created correctly

  Background:
    Given I have kubernetes_namespace defined

  Scenario: Namespace is named monitoring
    Then it must contain metadata
    And its metadata.name must be "monitoring"
