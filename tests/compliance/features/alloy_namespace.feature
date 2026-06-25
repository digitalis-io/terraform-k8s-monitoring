# Tests that modules/alloy creates the Kubernetes namespace with the correct
# name when create_namespace = true (the default).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe (read-only plan assertions).
#
# Note: terraform-compliance 1.15.1 looks for keys by regex match, not path
# traversal. Dotted paths like 'metadata.name' match no literal key. Use a
# plain key name — it recurses into nested dicts and finds the value.
# Labels with dot-containing key names are not traversable; label assertions
# live in the terratest suite (alloy_test.go).

Feature: Alloy namespace is created correctly

  Background:
    Given I have kubernetes_namespace defined

  Scenario: Namespace is named monitoring
    Then its name must be "monitoring"
