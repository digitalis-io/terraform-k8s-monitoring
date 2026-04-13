package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
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
