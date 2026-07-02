package test

import (
	"os"
	"path/filepath"
	"strings"
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

// TestAlloyModuleValidateWithIngress verifies that ingress with a valid
// hostname is accepted when faro_receiver.enabled = true — the chart's
// ingress feature only ever routes to the Faro receiver port.
func TestAlloyModuleValidateWithIngress(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"controller_type": "deployment",
				"replicas":        2,
				"faro_receiver":   map[string]interface{}{"enabled": true},
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

// TestAlloyModuleRejectsIngressWithoutFaroReceiver verifies that enabling
// ingress without faro_receiver.enabled is rejected — the chart's ingress
// feature has no general-purpose routing for other components.
func TestAlloyModuleRejectsIngressWithoutFaroReceiver(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"ingress": map[string]interface{}{
					"enabled": true,
					"host":    "alloy.example.com",
				},
			},
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "ingress.enabled without faro_receiver.enabled must be rejected")
	assert.Contains(t, err.Error(), "ingress.enabled requires faro_receiver.enabled")
}

// TestAlloyModuleRejectsFaroPortOutOfRange verifies that faro_receiver.port
// values outside 1-65535 are rejected.
func TestAlloyModuleRejectsFaroPortOutOfRange(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"faro_receiver": map[string]interface{}{"enabled": true, "port": 99999},
			},
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "faro_receiver.port out of range must be rejected")
	assert.Contains(t, err.Error(), "faro_receiver.port must be a valid TCP port")
}

// TestAlloyTemplateSetsFaroIngressPort verifies that the ingress block sets
// the chart's faroPort key when faro_enabled is true. The grafana/alloy
// chart's ingress feature always targets this fixed key regardless of any
// other component's port.
func TestAlloyTemplateSetsFaroIngressPort(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "faroPort:", "ingress block must set the chart's faroPort key when faro_enabled")
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

// TestAlloyModuleValidateCustomReleaseName verifies that release_name is
// accepted, so a second Alloy-based release (e.g. a Faro receiver gateway)
// can be deployed into the same namespace as a daemonset collector without
// colliding with the default "alloy" release name.
func TestAlloyModuleValidateCustomReleaseName(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"release_name": "faro-receiver",
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyModuleValidateCustomExtraPorts verifies that extra_ports is
// accepted and overrides the default OTLP ports.
func TestAlloyModuleValidateCustomExtraPorts(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"extra_ports": []map[string]interface{}{
					{"name": "faro-http", "port": 12347, "target_port": 12347},
				},
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyTemplateIndentsFirstLineOfCustomConfig verifies that the template
// indents the FIRST line of a custom alloy_config, not just subsequent lines.
// Terraform's indent() function skips the first line by design; the template
// must supply the leading indent itself or the rendered YAML block scalar
// becomes invalid (first line dedented below its parent key).
func TestAlloyTemplateIndentsFirstLineOfCustomConfig(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.NotContains(t, tmpl, "\n${ indent(6, alloy_config) }", "the custom alloy_config substitution must not rely on indent() alone for the first line")
	assert.Contains(t, tmpl, "      ${indent(6, alloy_config)}", "template must prefix the custom alloy_config substitution with a literal 6-space indent")
}

// TestAlloyModuleValidateFaroReceiverEnabled verifies that faro_receiver.enabled
// is accepted alongside sibling tempo/loki endpoints.
func TestAlloyModuleValidateFaroReceiverEnabled(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../modules/alloy",
		TerraformBinary: "tofu",
		NoColor:         true,
		Vars: map[string]interface{}{
			"alloy": map[string]interface{}{
				"controller_type": "deployment",
				"replicas":        2,
				"faro_receiver":   map[string]interface{}{"enabled": true},
				"tempo_endpoint":  "http://tempo.monitoring.svc.cluster.local:4317",
				"loki_endpoint":   "http://loki.monitoring.svc.cluster.local:3100",
			},
		},
	}

	terraform.InitAndValidate(t, opts)
}

// TestAlloyTemplateHasFaroReceiverComponent verifies that the template wires
// Alloy's faro.receiver component when faro_enabled is true, and that it has
// no metrics/Mimir wiring — faro.receiver only emits logs and traces.
func TestAlloyTemplateHasFaroReceiverComponent(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/helm-values/alloy.yaml.tftpl")
	require.NoError(t, err, "alloy helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "faro_enabled", "template must branch on the faro_enabled variable")
	assert.Contains(t, tmpl, "faro.receiver", "template must configure Alloy's faro.receiver component")
	assert.Contains(t, tmpl, "listen_port", "template must set the faro.receiver listen port from faro_port")
	assert.Contains(t, tmpl, "sourcemaps", "template must enable sourcemap support")
}

// TestAlloyExtraPortsDefaultsToFaroPortWhenEnabled verifies that main.tf
// selects a faro-http extra port by default when faro_receiver.enabled is
// true and the caller did not explicitly set extra_ports.
func TestAlloyExtraPortsDefaultsToFaroPortWhenEnabled(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/alloy/main.tf")
	require.NoError(t, err, "main.tf must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "local.faro_enabled", "main.tf must branch the extra_ports default on faro_enabled")
	assert.Contains(t, tmpl, "faro-http", "main.tf must default to a faro-http port when faro_receiver is enabled")
}

// TestAlloyVariablesHaveNoFaroMimirWiring verifies that faro_receiver has no
// mimir_endpoint field — Alloy's faro.receiver component has no metrics
// output, so a Mimir wiring surface there would be dead configuration.
func TestAlloyVariablesHaveNoFaroMimirWiring(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/alloy/variables.tf")
	require.NoError(t, err, "variables.tf must exist")

	content := string(vars)
	require.Contains(t, content, "faro_receiver = optional(object({", "variables.tf must declare the faro_receiver block")

	// Isolate the faro_receiver object body and assert it has no mimir field.
	start := strings.Index(content, "faro_receiver = optional(object({")
	end := strings.Index(content[start:], "}), {})")
	require.Greater(t, end, 0, "faro_receiver object body must be closed")
	body := content[start : start+end]
	assert.NotContains(t, body, "mimir", "faro_receiver must not declare a mimir_endpoint field")
}

// TestAlloyOutputsHaveFaroReceiverEndpoints verifies that outputs.tf declares
// the Faro receiver endpoint outputs, and that the OTLP endpoint outputs read
// the actual Helm release name rather than hardcoding "alloy" — required now
// that release_name is customizable.
func TestAlloyOutputsHaveFaroReceiverEndpoints(t *testing.T) {
	t.Parallel()

	outputs, err := os.ReadFile("../modules/alloy/outputs.tf")
	require.NoError(t, err, "outputs.tf must exist")

	content := string(outputs)
	assert.Contains(t, content, "faro_receiver_http_endpoint", "outputs.tf must declare faro_receiver_http_endpoint")
	assert.Contains(t, content, "faro_receiver_public_url", "outputs.tf must declare faro_receiver_public_url")
	assert.Contains(t, content, "helm_release.alloy.name", "otlp/faro endpoint outputs must read the actual release name, not a hardcoded \"alloy\"")
}

// TestAlloyCoexistsWithSecondFaroReceiverInstance verifies that two
// module.alloy instances — a default daemonset collector and a
// faro_receiver-enabled deployment — can be planned together in the same
// namespace without their Helm releases or namespace resources colliding.
func TestAlloyCoexistsWithSecondFaroReceiverInstance(t *testing.T) {
	t.Parallel()

	repoRoot, err := filepath.Abs("..")
	require.NoError(t, err, "must resolve repo root")

	dir := t.TempDir()
	alloySource := filepath.ToSlash(filepath.Join(repoRoot, "modules/alloy"))
	mainTf := `
terraform {
  required_providers {
    helm       = { source = "hashicorp/helm", version = "~> 2.17" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.36" }
  }
}

module "alloy" {
  source = "` + alloySource + `"
  alloy = {
    namespace = "monitoring"
  }
}

module "faro" {
  source = "` + alloySource + `"
  alloy = {
    release_name      = "faro-receiver"
    namespace         = "monitoring"
    create_namespace  = false
    controller_type   = "deployment"
    replicas          = 2
    faro_receiver     = { enabled = true }
  }
}
`
	require.NoError(t, os.WriteFile(dir+"/main.tf", []byte(mainTf), 0o644))

	opts := &terraform.Options{
		TerraformDir:    dir,
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.InitAndPlan(t, opts)
}
