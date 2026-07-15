# Tests that modules/mimir creates the Kubernetes namespace with the correct
# name when create_namespace = true (the default), planned from the
# mimir_defaults.tfvars fixture.
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# The create_namespace = false path (zero namespace resources) is asserted in
# the terratest suite (mimir_test.go), because terraform-compliance's
# "Given ... defined" step skips rather than fails on absence and so cannot
# assert a resource is NOT created.

Feature: Mimir namespace is created correctly

  Background:
    Given I have kubernetes_namespace defined

  Scenario: Namespace is named monitoring
    Then its name must be "monitoring"
