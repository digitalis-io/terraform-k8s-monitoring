package test

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// lokiHelmValues plans modules/loki with the given vars and returns the
// concatenated Helm `values` rendered for the loki release. Planning the module
// directly needs no cluster — helm_release/kubernetes_namespace creates are
// known-after-apply and do not contact the API at plan time.
func lokiHelmValues(t *testing.T, storage map[string]interface{}) string {
	t.Helper()

	opts := &terraform.Options{
		TerraformDir:    "../modules/loki",
		TerraformBinary: "tofu",
		NoColor:         true,
		PlanFilePath:    filepath.Join(t.TempDir(), "loki.plan"),
		Vars: map[string]interface{}{
			"loki": map[string]interface{}{
				"storage": storage,
			},
		},
	}

	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)
	res, ok := plan.ResourcePlannedValuesMap["helm_release.loki"]
	require.True(t, ok, "plan must contain helm_release.loki")

	values, ok := res.AttributeValues["values"].([]interface{})
	require.True(t, ok, "helm_release.loki must have a values list")

	var sb strings.Builder
	for _, v := range values {
		if s, ok := v.(string); ok {
			sb.WriteString(s)
		}
	}
	return sb.String()
}

// TestLokiEnablesExpandEnvWithS3Secret verifies that, when Loki authenticates to
// S3 via credentials injected as env vars (the module always creates a Secret
// and references $${AWS_ACCESS_KEY_ID} in the config), the rendered Helm values
// pass -config.expand-env=true to the components. Without the flag the grafana/loki
// chart does not expand $${VAR} and S3 auth fails silently. Regression guard for #23.
func TestLokiEnablesExpandEnvWithS3Secret(t *testing.T) {
	t.Parallel()

	values := lokiHelmValues(t, map[string]interface{}{
		"backend":          "s3",
		"s3_chunks_bucket": "my-loki-chunks",
		"s3_ruler_bucket":  "my-loki-ruler",
		"s3_region":        "us-east-1",
		"s3_access_key":    "AKIAEXAMPLE",
		"s3_secret_key":    "secretexample",
	})

	assert.Contains(t, values, "-config.expand-env=true",
		"S3 credential env refs require -config.expand-env=true or Loki reads them as literal strings")
	// The flag must accompany the env-var references it enables.
	assert.Contains(t, values, "AWS_ACCESS_KEY_ID",
		"S3 credentials must be injected as env vars via secretKeyRef")
}

// TestLokiNoExpandEnvForLocalStorage verifies the flag is only added when it is
// needed — a local-disk deployment references no env vars, so -config.expand-env
// must not be present.
func TestLokiNoExpandEnvForLocalStorage(t *testing.T) {
	t.Parallel()

	values := lokiHelmValues(t, map[string]interface{}{
		"backend": "local",
	})

	assert.NotContains(t, values, "-config.expand-env=true",
		"local storage references no env vars, so expand-env must not be set")
}
