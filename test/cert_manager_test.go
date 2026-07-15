package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// certManagerIssuerManifest plans modules/cert-manager with the given cert_manager
// vars and returns the rendered ClusterIssuer manifest (the cluster_issuer_manifest
// output). Planning needs no cluster — the manifest is a pure function of inputs.
func certManagerIssuerManifest(t *testing.T, certManager map[string]interface{}) string {
	t.Helper()

	opts := &terraform.Options{
		TerraformDir:    "../modules/cert-manager",
		TerraformBinary: "tofu",
		NoColor:         true,
		PlanFilePath:    filepath.Join(t.TempDir(), "cert-manager.plan"),
		Vars:            map[string]interface{}{"cert_manager": certManager},
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	out, ok := plan.RawPlan.PlannedValues.Outputs["cluster_issuer_manifest"]
	require.True(t, ok, "plan must expose the cluster_issuer_manifest output")
	manifest, ok := out.Value.(string)
	require.True(t, ok, "cluster_issuer_manifest must be a string")
	return manifest
}

// TestCertManagerDefaultIssuerIsSelfSigned verifies back-compatibility: with no
// issuer config the module still renders a self-signed ClusterIssuer.
func TestCertManagerDefaultIssuerIsSelfSigned(t *testing.T) {
	t.Parallel()
	manifest := certManagerIssuerManifest(t, map[string]interface{}{})
	assert.Contains(t, manifest, "selfSigned", "default issuer must be self-signed")
	assert.NotContains(t, manifest, "acme", "default issuer must not configure ACME")
}

// TestCertManagerAcmeIssuer verifies the ACME/Let's Encrypt issuer renders the
// server, email, and HTTP-01 ingress solver from the supplied config (#22).
func TestCertManagerAcmeIssuer(t *testing.T) {
	t.Parallel()
	manifest := certManagerIssuerManifest(t, map[string]interface{}{
		"cluster_issuer_name": "letsencrypt-prod",
		"issuer": map[string]interface{}{
			"type": "acme",
			"acme": map[string]interface{}{
				"email":                "ops@example.com",
				"solver_ingress_class": "nginx",
			},
		},
	})
	assert.Contains(t, manifest, "acme", "ACME issuer must render an acme block")
	assert.Contains(t, manifest, "ops@example.com", "ACME issuer must carry the contact email")
	assert.Contains(t, manifest, "acme-v02.api.letsencrypt.org", "ACME issuer must default to the Let's Encrypt directory")
	assert.Contains(t, manifest, "http01", "ACME issuer must configure the HTTP-01 solver")
	assert.NotContains(t, manifest, "selfSigned", "ACME issuer must not render a self-signed block")
}

// TestCertManagerCaIssuer verifies the CA issuer references the supplied secret.
func TestCertManagerCaIssuer(t *testing.T) {
	t.Parallel()
	manifest := certManagerIssuerManifest(t, map[string]interface{}{
		"issuer": map[string]interface{}{
			"type": "ca",
			"ca":   map[string]interface{}{"secret_name": "my-ca-keypair"},
		},
	})
	assert.Contains(t, manifest, "secretName", "CA issuer must reference a CA secret")
	assert.Contains(t, manifest, "my-ca-keypair", "CA issuer must use the supplied secret name")
}

// planCertManagerError returns the error from planning modules/cert-manager with
// the given vars, or nil if the plan succeeds.
func planCertManagerError(t *testing.T, certManager map[string]interface{}) error {
	t.Helper()
	opts := &terraform.Options{
		TerraformDir:    "../modules/cert-manager",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars:            map[string]interface{}{"cert_manager": certManager},
	}
	_, err := terraform.InitAndPlanE(t, opts)
	return err
}

// TestCertManagerRejectsInvalidIssuerName verifies the RFC 1123 validation guards
// against names that would otherwise be injected into the rendered manifest.
func TestCertManagerRejectsInvalidIssuerName(t *testing.T) {
	t.Parallel()
	err := planCertManagerError(t, map[string]interface{}{"cluster_issuer_name": "Bad_Name!"})
	require.Error(t, err, "an invalid ClusterIssuer name must be rejected")
	assert.Contains(t, err.Error(), "RFC 1123")
}

// TestCertManagerAcmeRequiresEmail verifies ACME issuers must supply a contact email.
func TestCertManagerAcmeRequiresEmail(t *testing.T) {
	t.Parallel()
	err := planCertManagerError(t, map[string]interface{}{
		"issuer": map[string]interface{}{"type": "acme"},
	})
	require.Error(t, err, "ACME issuer without an email must be rejected")
	assert.Contains(t, err.Error(), "email is required")
}

// TestCertManagerRejectsUnknownIssuerType verifies the issuer type enum is enforced.
func TestCertManagerRejectsUnknownIssuerType(t *testing.T) {
	t.Parallel()
	err := planCertManagerError(t, map[string]interface{}{
		"issuer": map[string]interface{}{"type": "vault"},
	})
	require.Error(t, err, "an unknown issuer type must be rejected")
	assert.Contains(t, err.Error(), "issuer.type must be one of")
}
