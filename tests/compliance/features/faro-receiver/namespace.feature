# Tests that modules/faro-receiver creates the Kubernetes namespace with the
# correct name when create_namespace = true (the default).
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe (read-only plan assertions).

Feature: Faro receiver namespace is created correctly

  Background:
    Given I have kubernetes_namespace defined

  Scenario: Namespace is named monitoring
    Then its name must be "monitoring"
