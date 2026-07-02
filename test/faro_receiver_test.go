package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestFaroReceiverModuleValidateDefaults verifies that the faro-receiver module
// passes terraform validate with all defaults (var.faro_receiver = {}).
func TestFaroReceiverModuleValidateDefaults(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/faro-receiver",
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.InitAndValidate(t, opts)
}

// TestFaroReceiverModuleValidateWithIngress verifies that ingress with a valid
// hostname is accepted.
func TestFaroReceiverModuleValidateWithIngress(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/faro-receiver",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"faro_receiver": map[string]interface{}{
				"ingress": map[string]interface{}{
					"enabled":    true,
					"host":       "faro.example.com",
					"class_name": "nginx",
					"tls_secret": "faro-tls",
				},
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestFaroReceiverModuleValidateWithAllEndpoints verifies that all sibling
// endpoint variables are accepted (exercises the built-in config template path).
func TestFaroReceiverModuleValidateWithAllEndpoints(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/faro-receiver",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"faro_receiver": map[string]interface{}{
				"tempo_endpoint": "http://tempo.monitoring.svc.cluster.local:4317",
				"loki_endpoint":  "http://loki.monitoring.svc.cluster.local:3100",
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestFaroReceiverModuleRejectsNonDeploymentControllerType verifies that
// controller_type values other than "deployment" are rejected.
func TestFaroReceiverModuleRejectsNonDeploymentControllerType(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/faro-receiver",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"faro_receiver": map[string]interface{}{
				"controller_type": "daemonset",
			},
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "controller_type != deployment must be rejected")
	assert.Contains(t, err.Error(), "controller_type must be 'deployment'")
}

// TestFaroReceiverModuleRejectsIngressWithoutHost verifies that enabling
// ingress without a host is rejected.
func TestFaroReceiverModuleRejectsIngressWithoutHost(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/faro-receiver",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"faro_receiver": map[string]interface{}{
				"ingress": map[string]interface{}{
					"enabled": true,
				},
			},
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "ingress.enabled without ingress.host must be rejected")
	assert.Contains(t, err.Error(), "ingress.host is required")
}

// TestFaroReceiverTemplateHasFaroReceiverComponent verifies that the Helm
// values template wires Alloy's faro.receiver component and listens on the
// configured port.
func TestFaroReceiverTemplateHasFaroReceiverComponent(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/faro-receiver/helm-values/faro-receiver.yaml.tftpl")
	require.NoError(t, err, "faro-receiver helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "faro.receiver", "template must configure Alloy's faro.receiver component")
	assert.Contains(t, tmpl, "listen_port", "template must set the faro.receiver listen port")
	assert.Contains(t, tmpl, "sourcemaps", "template must enable sourcemap support")
}

// TestFaroReceiverTemplateHasNoMimirWiring verifies that no Mimir/Prometheus
// remote_write surface exists in the template or variables. Alloy's
// faro.receiver component only emits logs and traces — it has no metrics
// output — so a mimir_endpoint variable would be dead configuration.
func TestFaroReceiverTemplateHasNoMimirWiring(t *testing.T) {
	t.Parallel()

	tmpl, err := os.ReadFile("../modules/faro-receiver/helm-values/faro-receiver.yaml.tftpl")
	require.NoError(t, err, "faro-receiver helm values template must exist")
	assert.NotContains(t, string(tmpl), "prometheus.remote_write", "template must not reference a metrics exporter faro.receiver cannot feed")

	vars, err := os.ReadFile("../modules/faro-receiver/variables.tf")
	require.NoError(t, err, "variables.tf must exist")
	assert.NotContains(t, string(vars), "mimir_endpoint", "variables.tf must not declare an unusable mimir_endpoint variable")
}

// TestFaroReceiverTemplateHasExtraPort verifies that the template exposes the
// Faro receiver HTTP port so the chart creates a Service with that port.
func TestFaroReceiverTemplateHasExtraPort(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/faro-receiver/helm-values/faro-receiver.yaml.tftpl")
	require.NoError(t, err, "faro-receiver helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "extraPorts:", "template must declare extraPorts for the Faro receiver")
	assert.Contains(t, tmpl, "faro-http", "template must name the Faro receiver port")
}

// TestFaroReceiverVariablesHaveControllerTypeValidation verifies that
// variables.tf restricts controller_type to "deployment".
func TestFaroReceiverVariablesHaveControllerTypeValidation(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/faro-receiver/variables.tf")
	require.NoError(t, err, "variables.tf must exist")

	content := string(vars)
	assert.Contains(t, content, `var.faro_receiver.controller_type == "deployment"`, "variables.tf must validate controller_type is deployment-only")
	assert.Contains(t, content, "controller_type must be 'deployment'", "validation error message must explain the restriction")
}

// TestFaroReceiverOutputsHaveReceiverEndpoints verifies that outputs.tf
// declares the in-cluster and public receiver endpoint outputs.
func TestFaroReceiverOutputsHaveReceiverEndpoints(t *testing.T) {
	t.Parallel()

	outputs, err := os.ReadFile("../modules/faro-receiver/outputs.tf")
	require.NoError(t, err, "outputs.tf must exist")

	content := string(outputs)
	assert.Contains(t, content, "receiver_http_endpoint", "outputs.tf must declare receiver_http_endpoint")
	assert.Contains(t, content, "receiver_public_url", "outputs.tf must declare receiver_public_url")
}
