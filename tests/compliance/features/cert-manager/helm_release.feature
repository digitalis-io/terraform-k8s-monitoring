# Tests that modules/cert-manager deploys the cert-manager Helm chart from the
# Jetstack OCI registry into the configured namespace, planned from the
# cert_manager_defaults.tfvars fixture.
#
# The ClusterIssuer itself is applied via a terraform_data/local-exec provisioner
# (its manifest is not a plannable resource attribute), so issuer behaviour —
# self-signed / ACME / CA rendering and name validation — is covered by the
# terratest suite (cert_manager_test.go).

Feature: cert-manager Helm release is configured correctly

  Background:
    Given I have helm_release defined

  Scenario: Release uses the cert-manager chart
    Then its chart must be "cert-manager"

  Scenario: Release pulls from the Jetstack OCI registry
    Then its repository must be "oci://quay.io/jetstack/charts"

  Scenario: Release is deployed into the cert-manager namespace
    Then its namespace must be "cert-manager"
