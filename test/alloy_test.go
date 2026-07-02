package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestAlloyModuleValidateDefaults verifies that the alloy module passes
// terraform validate with all defaults (var.alloy = {}).
func TestAlloyModuleValidateDefaults(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleValidateDaemonset verifies that controller_type = "daemonset"
// is accepted.
func TestAlloyModuleValidateDaemonset(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"controller_type": "daemonset",
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleValidateDeployment verifies that controller_type = "deployment"
// with a replica count is accepted.
func TestAlloyModuleValidateDeployment(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"controller_type": "deployment",
				"replicas":        2,
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleValidateStatefulset verifies that controller_type = "statefulset"
// with WAL persistence enabled is accepted.
func TestAlloyModuleValidateStatefulset(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"controller_type": "statefulset",
				"persistence": map[string]interface{}{
					"enabled": true,
					"size":    "20Gi",
				},
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleValidateWithIngress verifies that ingress with a valid hostname
// is accepted.
func TestAlloyModuleValidateWithIngress(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"ingress": map[string]interface{}{
					"enabled":    true,
					"host":       "alloy.example.com",
					"class_name": "nginx",
					"tls_secret": "alloy-tls",
				},
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleValidateWithAllEndpoints verifies that all sibling endpoint
// variables are accepted (exercises the built-in River config template path).
func TestAlloyModuleValidateWithAllEndpoints(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"loki_endpoint":      "http://loki.monitoring.svc.cluster.local:3100",
				"tempo_endpoint":     "http://tempo.monitoring.svc.cluster.local:4317",
				"mimir_endpoint":     "http://mimir-nginx.monitoring.svc.cluster.local/api/v1/push",
				"mimir_tenant_id":    "anonymous",
				"pyroscope_endpoint": "http://pyroscope.monitoring.svc.cluster.local:4040",
				"otel_grpc_endpoint": "http://otel.monitoring.svc.cluster.local:4317",
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyTemplateHasControllerType verifies that the Helm values template
// renders the controller.type field from the controller_type variable.
func TestAlloyTemplateHasControllerType(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "controller_type", "template must use controller_type variable")
	assert.Contains(t, tmpl, "controller:", "template must set alloy.controller block")
	assert.Contains(t, tmpl, "type: ${controller_type}", "template must render controller.type from variable")
}

// TestAlloyTemplateHasExtraPorts verifies that the template exposes OTLP gRPC
// and HTTP ports in the Helm values so the chart creates a Service with those ports.
func TestAlloyTemplateHasExtraPorts(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "4317", "template must expose OTLP gRPC port 4317")
	assert.Contains(t, tmpl, "4318", "template must expose OTLP HTTP port 4318")
	assert.Contains(t, tmpl, "extraPorts:", "template must declare extraPorts for OTLP")
}

// TestAlloyTemplateHasServiceAccountAnnotations verifies that the Helm values
// template renders serviceAccount annotations from the service_account_annotations
// map. Users supply IRSA / Workload Identity annotations; the module creates no IAM.
func TestAlloyTemplateHasServiceAccountAnnotations(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "serviceAccount", "template must configure Alloy service account")
	assert.Contains(t, tmpl, "service_account_annotations", "template must iterate over service_account_annotations map")

	vars, err := os.ReadFile("../modules/alloy/variables.tf")
	require.NoError(t, err, "variables.tf must exist")
	assert.Contains(t, string(vars), "service_account_annotations", "variables.tf must declare service_account_annotations")
}

// TestAlloyTemplateHasIngressTLS verifies that the ingress block in the Helm
// values template includes TLS, ingressClassName, and annotation support.
func TestAlloyTemplateHasIngressTLS(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "ingressClassName:", "ingress block must set ingressClassName")
	assert.Contains(t, tmpl, "tls:", "ingress block must configure TLS")
	assert.Contains(t, tmpl, "secretName:", "ingress block must reference a TLS secret")
	assert.Contains(t, tmpl, "ingress_annotations", "ingress block must iterate over annotations")
}

// TestAlloyTemplateHasBuiltInRiverConfig verifies that the template renders a
// built-in River/Alloy config when sibling endpoints are provided. It checks that
// the key River component names appear in the template so the pipeline is wired.
func TestAlloyTemplateHasBuiltInRiverConfig(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "otelcol.receiver.otlp", "built-in config must include OTLP receiver")
	assert.Contains(t, tmpl, "otelcol.processor.batch", "built-in config must include batch processor")
	assert.Contains(t, tmpl, "otelcol.exporter.debug", "built-in config must include debug fallback exporter")
	assert.Contains(t, tmpl, "loki.write", "built-in config must include Loki write component")
	assert.Contains(t, tmpl, "prometheus.remote_write", "built-in config must include Prometheus remote_write for Mimir")
	assert.Contains(t, tmpl, "otelcol.exporter.otlp", "built-in config must include OTLP exporter for Tempo")
	assert.Contains(t, tmpl, "X-Scope-OrgID", "Mimir remote_write must include X-Scope-OrgID header")
}

// TestAlloyTemplateHasPersistence verifies that the template renders WAL
// persistence (volumeClaimTemplates) when persistence_enabled is set.
func TestAlloyTemplateHasPersistence(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "persistence_enabled", "template must gate persistence on persistence_enabled variable")
	assert.Contains(t, tmpl, "volumeClaimTemplates:", "template must include volumeClaimTemplates block for WAL persistence")
	assert.Contains(t, tmpl, "storagePath:", "template must set alloy.storagePath")
}

// TestAlloyVariablesHaveControllerTypeValidation verifies that variables.tf
// declares a validation block rejecting invalid controller_type values.
func TestAlloyVariablesHaveControllerTypeValidation(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/alloy/variables.tf")
	require.NoError(t, err, "variables.tf must exist")

	content := string(vars)
	assert.Contains(t, content, `contains(["daemonset", "deployment", "statefulset"]`, "variables.tf must validate controller_type against the allowed set")
	assert.Contains(t, content, "controller_type must be one of", "validation error message must name the valid values")
}

// TestAlloyVariablesHaveIngressHostValidation verifies that variables.tf
// declares a validation block requiring ingress.host when ingress.enabled = true.
func TestAlloyVariablesHaveIngressHostValidation(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/alloy/variables.tf")
	require.NoError(t, err, "variables.tf must exist")

	content := string(vars)
	assert.Contains(t, content, "ingress.host is required when ingress.enabled", "variables.tf must validate that ingress.host is set when ingress is enabled")
}

// TestAlloyOutputsHaveOTLPEndpoints verifies that outputs.tf declares the OTLP
// gRPC and HTTP endpoint outputs that consuming modules wire to applications.
func TestAlloyOutputsHaveOTLPEndpoints(t *testing.T) {
	t.Parallel()

	outputs, err := os.ReadFile("../modules/alloy/outputs.tf")
	require.NoError(t, err, "outputs.tf must exist")

	content := string(outputs)
	assert.Contains(t, content, "otlp_grpc_endpoint", "outputs.tf must declare otlp_grpc_endpoint")
	assert.Contains(t, content, "otlp_http_endpoint", "outputs.tf must declare otlp_http_endpoint")
	assert.Contains(t, content, "4317", "otlp_grpc_endpoint must reference port 4317")
	assert.Contains(t, content, "4318", "otlp_http_endpoint must reference port 4318")
}

// TestAlloyModuleValidateSensitiveDataCustomRules verifies that custom_rules
// entries with valid "hash"/"delete" actions are accepted.
func TestAlloyModuleValidateSensitiveDataCustomRules(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"sensitive_data": map[string]interface{}{
					"action": "hash",
					"salt":   "test-salt",
					"custom_rules": map[string]interface{}{
						"user.ssn":       "delete",
						"transaction.id": "hash",
					},
				},
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleValidateSensitiveDataDisabled verifies that the processor
// can be explicitly disabled.
func TestAlloyModuleValidateSensitiveDataDisabled(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"sensitive_data": map[string]interface{}{
					"enabled": false,
				},
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleRejectsInvalidSensitiveDataAction verifies that an
// out-of-enum sensitive_data.action fails validation with a clear error.
func TestAlloyModuleRejectsInvalidSensitiveDataAction(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"sensitive_data": map[string]interface{}{
					"action": "encrypt",
				},
			},
		},
	}

	terraform.Init(t, opts)
	_, err := terraform.PlanE(t, opts)
	require.Error(t, err, "plan must fail when sensitive_data.action is not 'hash' or 'delete'")
	assert.Contains(t, err.Error(), "sensitive_data.action must be 'hash' or 'delete'")
}

// TestAlloyModuleRejectsInvalidSensitiveDataCustomRuleAction verifies that an
// out-of-enum action in custom_rules fails validation.
func TestAlloyModuleRejectsInvalidSensitiveDataCustomRuleAction(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"sensitive_data": map[string]interface{}{
					"custom_rules": map[string]interface{}{
						"user.ssn": "encrypt",
					},
				},
			},
		},
	}

	terraform.Init(t, opts)
	_, err := terraform.PlanE(t, opts)
	require.Error(t, err, "plan must fail when a custom_rules action is not 'hash' or 'delete'")
	assert.Contains(t, err.Error(), "sensitive_data.custom_rules values must be 'hash' or 'delete'")
}

// TestAlloyTemplateHasSensitiveDataProcessor verifies that the Helm values
// template wires the sensitive-data transform processor into the built-in
// pipeline and routes the receiver through it when enabled.
func TestAlloyTemplateHasSensitiveDataProcessor(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, `otelcol.processor.transform "sensitive_data"`, "template must declare the sensitive-data transform processor")
	assert.Contains(t, tmpl, "otelcol.processor.transform.sensitive_data.input", "receiver must route through the transform processor when enabled")
	assert.Contains(t, tmpl, "sensitive_data_statements", "template must iterate over the precomputed sensitive_data_statements list")
	assert.Contains(t, tmpl, `error_mode = "propagate"`, "processor must fail loudly (not fail open) on a malformed rule")

	main, err := os.ReadFile("../modules/alloy/main.tf")
	require.NoError(t, err, "main.tf must exist")

	mainContent := string(main)
	assert.Contains(t, mainContent, "delete_key(attributes", "main.tf must generate the delete action statement")
	assert.Contains(t, mainContent, "SHA256(", "main.tf must generate the hash action statement")
	assert.Contains(t, mainContent, "alloy_sensitive_data_salt", "main.tf must support salting the hash")
}

// TestAlloyVariablesHaveSensitiveDataValidation verifies that variables.tf
// declares validation blocks for sensitive_data.action and custom_rules values.
func TestAlloyVariablesHaveSensitiveDataValidation(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/alloy/variables.tf")
	require.NoError(t, err, "variables.tf must exist")

	content := string(vars)
	assert.Contains(t, content, "sensitive_data.action must be", "variables.tf must validate sensitive_data.action against the allowed set")
	assert.Contains(t, content, "sensitive_data.custom_rules values must be", "variables.tf must validate sensitive_data.custom_rules action values")
}

// TestAlloyVariablesSensitiveDataEnabledByDefault verifies that the
// sensitive-data processor defaults to enabled.
func TestAlloyVariablesSensitiveDataEnabledByDefault(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/alloy/variables.tf")
	require.NoError(t, err, "variables.tf must exist")

	content := string(vars)
	assert.Contains(t, content, `enabled               = optional(bool, true)`, "sensitive_data.enabled must default to true")
}

// TestAlloyExampleValidate verifies that examples/alloy-basic passes
// terraform validate. Requires Terraform >= 1.9 (mimir module constraint).
func TestAlloyExampleValidate(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../examples/alloy-basic",
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.InitAndValidate(t, opts)
}
