package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestMimirMinimalValidate verifies that the minimal example (local disk backend)
// passes `tofu validate` without requiring a live Kubernetes cluster.
func TestMimirMinimalValidate(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../examples/minimal",
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.InitAndValidate(t, opts)
}

// TestMimirLocalStoragePathsDoNotOverlap verifies that the template sets
// ruler.rule_path to a directory that cannot overlap with blocks_storage or
// ruler_storage filesystem dirs. Mimir rejects configs where these paths share
// a common prefix (e.g. /data vs /data/tsdb).
func TestMimirLocalStoragePathsDoNotOverlap(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/mimir/helm-values/mimir.yaml.tftpl")
	require.NoError(t, err, "helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "rule_path:", "ruler.rule_path must be set to avoid path overlap with blocks storage")
	assert.Contains(t, tmpl, "ruler-tmp", "ruler.rule_path must be distinct from storage dirs")
	assert.Contains(t, tmpl, "alertmanager-tmp", "alertmanager.data_dir must be distinct from alertmanager_storage dirs")
	assert.Contains(t, tmpl, "compactor-tmp", "compactor.data_dir must be distinct from storage dirs")
	// ingester uses blocks_storage.tsdb.dir — no separate data_dir field exists in ingester.Config
	assert.NotContains(t, tmpl, "ingester-wal", "ingester.wal is not a valid Mimir config field")
}

// TestMimirIngressTemplateHasTLS verifies that the Helm values template includes
// the TLS section, ingressClassName, and annotation support when ingress is enabled.
// This guards against regressions where TLS is accidentally removed from the template.
//
// Note: the variable validation that requires ingress_host when ingress_enabled=true
// is a plan-time check (child module validations are not evaluated by `tofu validate`).
// That behaviour is covered by integration tests (requires a live cluster).
func TestMimirIngressTemplateHasTLS(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/mimir/helm-values/mimir.yaml.tftpl")
	require.NoError(t, err, "helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "ingressClassName:", "ingress block must set ingressClassName")
	assert.Contains(t, tmpl, "tls:", "ingress block must configure TLS")
	assert.Contains(t, tmpl, "secretName:", "ingress block must reference a TLS secret")
	// Annotations are rendered dynamically; verify the for-loop is present
	assert.Contains(t, tmpl, "ingress_annotations", "ingress block must iterate over annotations")

	// The cert-manager default belongs in the variable definition, not the template
	vars, err := os.ReadFile("../modules/mimir/variables.tf")
	require.NoError(t, err, "variables.tf must exist")
	assert.Contains(t, string(vars), "cert-manager.io/cluster-issuer", "cert-manager annotation must be the default for ingress_annotations")
}

// TestMimirS3Validate verifies that the module validates correctly when S3
// storage variables are supplied. No buckets are created by the module —
// caller must pre-create them and pass the names in.
func TestMimirS3Validate(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../examples/minimal",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"mimir": map[string]interface{}{
				"storage": map[string]interface{}{
					"backend":               "s3",
					"s3_blocks_bucket":      "my-mimir-blocks",
					"s3_ruler_bucket":       "my-mimir-ruler",
					"s3_alertmanager_bucket": "my-mimir-alertmanager",
					"s3_region":             "us-east-1",
				},
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}
