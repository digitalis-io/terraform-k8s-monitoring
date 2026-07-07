package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestPrometheusMinimalValidate verifies that the minimal example passes
// `tofu validate` with the prometheus module present.
func TestPrometheusMinimalValidate(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir:    "../examples/minimal",
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.InitAndValidate(t, opts)
}

// TestPrometheusTemplateHasMimirWiring verifies that the Helm values template
// includes conditional remote_write and Grafana additionalDataSources blocks
// so Prometheus can ship metrics to Mimir and Grafana can query them.
func TestPrometheusTemplateHasMimirWiring(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/prometheus/helm-values/prometheus.yaml.tftpl")
	require.NoError(t, err, "prometheus helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "mimir_remote_write_url", "template must support conditional remote_write to Mimir")
	assert.Contains(t, tmpl, "remoteWrite", "template must include remoteWrite block for Mimir")
	assert.Contains(t, tmpl, "mimir_datasource_url", "template must support conditional Grafana datasource for Mimir")
	assert.Contains(t, tmpl, "additionalDataSources", "template must configure Grafana additionalDataSources for Mimir")
}

// TestPrometheusIngressTemplateHasTLS verifies that the Helm values template
// includes TLS, ingressClassName, and annotation support for the Grafana ingress.
func TestPrometheusIngressTemplateHasTLS(t *testing.T) {
	t.Parallel()

	content, err := os.ReadFile("../modules/prometheus/helm-values/prometheus.yaml.tftpl")
	require.NoError(t, err, "prometheus helm values template must exist")

	tmpl := string(content)
	assert.Contains(t, tmpl, "ingressClassName:", "ingress block must set ingressClassName")
	assert.Contains(t, tmpl, "tls:", "ingress block must configure TLS")
	assert.Contains(t, tmpl, "secretName:", "ingress block must reference a TLS secret")
	assert.Contains(t, tmpl, "ingress_annotations", "ingress block must iterate over annotations")

	vars, err := os.ReadFile("../modules/prometheus/variables.tf")
	require.NoError(t, err, "prometheus variables.tf must exist")
	assert.Contains(t, string(vars), "cert-manager.io/cluster-issuer", "cert-manager annotation must be the default for ingress_annotations")
}

// TestPrometheusComponentTogglesWired verifies that each per-component enable
// toggle is exposed as a variable and wired to the matching kube-prometheus-stack
// chart value, so a caller can slim the stack down to a Grafana-only install.
func TestPrometheusComponentTogglesWired(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/prometheus/variables.tf")
	require.NoError(t, err, "prometheus variables.tf must exist")
	tmpl, err := os.ReadFile("../modules/prometheus/helm-values/prometheus.yaml.tftpl")
	require.NoError(t, err, "prometheus helm values template must exist")

	// (variable name -> chart value key it must render).
	toggles := map[string]string{
		"prometheus_enabled":          "enabled: ${prometheus_enabled}",
		"prometheus_operator_enabled": "prometheusOperator:",
		"kube_state_metrics_enabled":  "kubeStateMetrics:",
		"node_exporter_enabled":       "nodeExporter:",
		"default_rules_enabled":       "defaultRules:",
	}
	for v, key := range toggles {
		assert.Contains(t, string(vars), v, "variables.tf must expose the %q toggle", v)
		assert.Contains(t, string(tmpl), key, "template must render the chart key for %q", v)
	}

	// Both the parent-chart and subchart spellings are required to fully toggle
	// kube-state-metrics and node-exporter across chart versions.
	assert.Contains(t, string(tmpl), "kube-state-metrics:", "template must toggle the kube-state-metrics subchart")
	assert.Contains(t, string(tmpl), "prometheus-node-exporter:", "template must toggle the prometheus-node-exporter subchart")
}

// TestPrometheusGrafanaDatabasePasswordNeverInValues verifies the external-DB
// password is injected via a Kubernetes secretKeyRef and is never rendered
// directly into the Helm values.
func TestPrometheusGrafanaDatabasePasswordNeverInValues(t *testing.T) {
	t.Parallel()

	tmpl, err := os.ReadFile("../modules/prometheus/helm-values/prometheus.yaml.tftpl")
	require.NoError(t, err, "prometheus helm values template must exist")
	main, err := os.ReadFile("../modules/prometheus/main.tf")
	require.NoError(t, err, "prometheus main.tf must exist")

	// Password reaches Grafana only as an env var sourced from a Secret.
	assert.Contains(t, string(tmpl), "GF_DATABASE_PASSWORD", "template must inject the DB password as an env var")
	assert.Contains(t, string(tmpl), "secretKeyRef", "template must source the password from a Secret")

	// The plaintext password must never be interpolated into the rendered values.
	assert.NotContains(t, string(tmpl), "${grafana_database.password}",
		"template must NOT render the plaintext password into the Helm values")

	// The module creates an Opaque Secret only for the plaintext-password path.
	assert.Contains(t, string(main), `resource "kubernetes_secret" "grafana_database"`,
		"main.tf must create a Secret to hold a plaintext DB password")
	assert.Contains(t, string(main), "grafana_db_create_secret",
		"secret creation must be gated on the plaintext-password path")
}

// TestPrometheusGrafanaDatabaseValidations verifies the guard rails on the
// grafana_database and grafana_replicas variables.
func TestPrometheusGrafanaDatabaseValidations(t *testing.T) {
	t.Parallel()

	vars, err := os.ReadFile("../modules/prometheus/variables.tf")
	require.NoError(t, err, "prometheus variables.tf must exist")
	s := string(vars)

	assert.Contains(t, s, "grafana_replicas", "grafana_replicas variable must exist")
	assert.Contains(t, s, "grafana_replicas > 1 requires grafana_database",
		"replicas > 1 must require an external database")
	assert.Contains(t, s, `ssl_mode is only supported for type = \"postgres\"`,
		"ssl_mode must be validated as postgres-only")
	assert.Contains(t, s, "set at most one of password or password_secret",
		"password and password_secret must be mutually exclusive")
	assert.Contains(t, s, "host:port", "grafana_database.host must be validated as host:port")
}
