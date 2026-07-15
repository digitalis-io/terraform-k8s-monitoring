package test

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const grafanaRulesWebhookMarker = "fixture-placeholder-not-a-secret"

// planGrafanaRules plans modules/grafana-rules with Slack + PagerDuty enabled and
// returns the plan struct. Planning needs no cluster.
func planGrafanaRules(t *testing.T) *terraform.PlanStruct {
	t.Helper()
	opts := &terraform.Options{
		TerraformDir:    "../modules/grafana-rules",
		TerraformBinary: "tofu",
		NoColor:         true,
		PlanFilePath:    filepath.Join(t.TempDir(), "grafana-rules.plan"),
		Vars: map[string]interface{}{
			"grafana_rules": map[string]interface{}{
				"namespace": "monitoring",
				"slack": map[string]interface{}{
					"enabled":     true,
					"webhook_url": "https://hooks.slack.example/T000/B000/" + grafanaRulesWebhookMarker,
					"channel":     "#alerts",
				},
				"pagerduty": map[string]interface{}{
					"enabled":         true,
					"integration_key": grafanaRulesWebhookMarker,
				},
			},
		},
	}
	return terraform.InitAndPlanAndShowWithStruct(t, opts)
}

// TestGrafanaRulesContactPointsUseSecret verifies the credential-bearing contact
// points are provisioned as a Secret (#25).
func TestGrafanaRulesContactPointsUseSecret(t *testing.T) {
	t.Parallel()
	plan := planGrafanaRules(t)

	res, ok := plan.ResourcePlannedValuesMap["kubernetes_secret.grafana_contact_points[0]"]
	require.True(t, ok, "contact points must be provisioned as a kubernetes_secret")
	assert.Equal(t, "Opaque", res.AttributeValues["type"], "the contact-points Secret must be Opaque")
}

// TestGrafanaRulesNoCredentialsInConfigMap verifies that no ConfigMap carries the
// Slack webhook URL / PagerDuty integration key — ConfigMaps are plaintext with
// weaker RBAC than Secrets (#25).
func TestGrafanaRulesNoCredentialsInConfigMap(t *testing.T) {
	t.Parallel()
	plan := planGrafanaRules(t)

	for addr, res := range plan.ResourcePlannedValuesMap {
		if !strings.HasPrefix(addr, "kubernetes_config_map.") {
			continue
		}
		// Render the whole ConfigMap's attributes and assert the credential marker
		// is absent from any of them.
		rendered := fmt.Sprintf("%v", res.AttributeValues)
		assert.NotContains(t, rendered, grafanaRulesWebhookMarker,
			"ConfigMap %s must not contain contact-point credentials", addr)
	}
}
