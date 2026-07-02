# Sensitive-data (PII) processor is enabled by default and configurable via
# custom_rules / disabling. Deep River-config content assertions (which fields
# get hashed vs deleted, salt wiring) live in test/alloy_test.go against the
# rendered template — terraform-compliance here only confirms the release
# still plans correctly for each configuration shape.
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).
# Scenarios are parallel-safe.

Feature: Alloy sensitive-data processor configuration

  Background:
    Given I have helm_release defined

  Scenario: Release still targets the alloy chart with custom sensitive-data rules
    Then its chart must be "alloy"

  Scenario: Release still targets the monitoring namespace with custom sensitive-data rules
    Then its namespace must be "monitoring"

  Scenario: Release still plans correctly with the sensitive-data processor disabled
    Then its chart must be "alloy"
