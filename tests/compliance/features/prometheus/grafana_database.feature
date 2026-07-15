# Tests that supplying grafana_database with a plaintext password makes the
# module plan a managed Kubernetes Secret to hold it, rather than embedding the
# password in the Helm release values. Run against the
# prometheus_grafana_db_plaintext fixture.
#
# The password_secret (existing-Secret) path is covered by the terratest suite
# (prometheus_test.go): terraform-compliance skips — rather than fails — a
# scenario whose resource type is absent, so it cannot assert the Secret's
# ABSENCE, only its presence.
#
# Read-only against the plan — no teardown needed (bdd-guidelines Rule 4).

Feature: Grafana external database password is held in a managed Secret

  Background:
    Given I have kubernetes_secret defined

  Scenario: The module creates the prometheus-grafana-db Secret
    Then its name must be "prometheus-grafana-db"

  Scenario: The Secret lives in the monitoring namespace
    Then its namespace must be "monitoring"

  Scenario: The Secret is an Opaque secret
    Then its type must be "Opaque"
