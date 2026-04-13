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
