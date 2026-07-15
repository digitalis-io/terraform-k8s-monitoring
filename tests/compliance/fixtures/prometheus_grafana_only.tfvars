# Grafana-only fixture — every metrics component disabled, Grafana kept.
# Verifies the helm release survives with all component toggles off (CRDs are
# still installed by the chart regardless of these toggles).
prometheus = {
  prometheus_enabled          = false
  prometheus_operator_enabled = false
  kube_state_metrics_enabled  = false
  node_exporter_enabled       = false
  default_rules_enabled       = false
  alertmanager_enabled        = false
  grafana_enabled             = true
}
