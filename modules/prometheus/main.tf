locals {
  grafana_db = var.prometheus.grafana_database

  # Create a Secret from a plaintext password only when one is given and the
  # caller has not referenced an existing Secret.
  # try(..., false) guards the null-object case: OpenTofu <1.11 eagerly evaluates
  # both sides of `&&`, so the `grafana_db != null &&` guard still errors on the
  # attribute access when grafana_database is unset (the default).
  grafana_db_create_secret = try(
    local.grafana_db != null &&
    local.grafana_db.password_secret == null &&
    local.grafana_db.password != "",
    false
  )

  # Resolve where GF_DATABASE_PASSWORD is sourced from: an existing Secret, the
  # one this module creates, or null (no password env — passwordless / IAM auth).
  grafana_db_secret = (
    local.grafana_db == null ? null :
    local.grafana_db.password_secret != null ? local.grafana_db.password_secret :
    local.grafana_db_create_secret ? { name = "prometheus-grafana-db", field = "password" } :
    null
  )
}

resource "kubernetes_secret" "grafana_database" {
  count = local.grafana_db_create_secret ? 1 : 0

  metadata {
    name      = "prometheus-grafana-db"
    namespace = var.prometheus.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    password = local.grafana_db.password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.prometheus]
}

resource "kubernetes_namespace" "prometheus" {
  count = var.prometheus.create_namespace ? 1 : 0

  metadata {
    name = var.prometheus.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.prometheus.namespace_labels)

    annotations = merge({
    }, var.prometheus.namespace_annotations)
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus.chart_version
  namespace  = var.prometheus.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    sensitive(templatefile("${path.module}/helm-values/prometheus.yaml.tftpl", {
      retention            = var.prometheus.retention
      storage_size         = var.prometheus.storage_size
      storage_class        = var.prometheus.storage_class
      grafana_enabled      = var.prometheus.grafana_enabled
      alertmanager_enabled = var.prometheus.alertmanager_enabled
      namespace            = var.prometheus.namespace

      prometheus_enabled          = var.prometheus.prometheus_enabled
      prometheus_operator_enabled = var.prometheus.prometheus_operator_enabled
      kube_state_metrics_enabled  = var.prometheus.kube_state_metrics_enabled
      node_exporter_enabled       = var.prometheus.node_exporter_enabled
      default_rules_enabled       = var.prometheus.default_rules_enabled

      grafana_replicas  = var.prometheus.grafana_replicas
      grafana_database  = local.grafana_db
      grafana_db_secret = local.grafana_db_secret

      grafana_ingress_enabled     = var.prometheus.grafana_ingress.enabled
      grafana_ingress_host        = var.prometheus.grafana_ingress.host
      grafana_ingress_class_name  = var.prometheus.grafana_ingress.class_name
      grafana_ingress_tls_secret  = var.prometheus.grafana_ingress.tls_secret != "" ? var.prometheus.grafana_ingress.tls_secret : "${var.prometheus.namespace}-grafana-tls"
      grafana_ingress_annotations = var.prometheus.grafana_ingress.annotations

      prometheus_ingress_enabled     = var.prometheus.prometheus_ingress.enabled
      prometheus_ingress_host        = var.prometheus.prometheus_ingress.host
      prometheus_ingress_class_name  = var.prometheus.prometheus_ingress.class_name
      prometheus_ingress_tls_secret  = var.prometheus.prometheus_ingress.tls_secret != "" ? var.prometheus.prometheus_ingress.tls_secret : "${var.prometheus.namespace}-prometheus-tls"
      prometheus_ingress_annotations = var.prometheus.prometheus_ingress.annotations

      alertmanager_ingress_enabled     = var.prometheus.alertmanager_ingress.enabled
      alertmanager_ingress_host        = var.prometheus.alertmanager_ingress.host
      alertmanager_ingress_class_name  = var.prometheus.alertmanager_ingress.class_name
      alertmanager_ingress_tls_secret  = var.prometheus.alertmanager_ingress.tls_secret != "" ? var.prometheus.alertmanager_ingress.tls_secret : "${var.prometheus.namespace}-alertmanager-tls"
      alertmanager_ingress_annotations = var.prometheus.alertmanager_ingress.annotations

      mimir_remote_write_url = var.prometheus.mimir_remote_write_url
      mimir_datasource_url   = var.prometheus.mimir_datasource_url
      mimir_tenant_id        = var.prometheus.mimir_tenant_id

      loki_datasource_url      = var.prometheus.loki_datasource_url
      loki_trace_id_field      = var.prometheus.loki_trace_id_field
      tempo_datasource_url     = var.prometheus.tempo_datasource_url
      pyroscope_datasource_url = var.prometheus.pyroscope_datasource_url
      tempo_profile_type_id    = var.prometheus.tempo_profile_type_id
      clickhouse_datasource    = var.prometheus.clickhouse_datasource

      grafana_plugins           = var.prometheus.grafana_plugins
      grafana_dashboard_imports = var.prometheus.grafana_dashboard_imports

      requests_cpu    = var.prometheus.resources.requests_cpu
      requests_memory = var.prometheus.resources.requests_memory
      limits_cpu      = var.prometheus.resources.limits_cpu
      limits_memory   = var.prometheus.resources.limits_memory
    }))
  ]

  depends_on = [kubernetes_namespace.prometheus, kubernetes_secret.grafana_database]
}

locals {
  bundled_dashboards = {
    for f in fileset("${path.module}/dashboards", "*.json") :
    f => file("${path.module}/dashboards/${f}")
  }
  all_dashboards = merge(local.bundled_dashboards, var.prometheus.extra_dashboards)
}

# One ConfigMap per dashboard JSON — bundled files merged with caller-supplied extra_dashboards.
# The Grafana sidecar watches for the grafana_dashboard label and auto-loads them.
resource "kubernetes_config_map" "grafana_dashboard" {
  for_each = var.prometheus.grafana_enabled ? local.all_dashboards : {}

  metadata {
    name      = "grafana-dashboard-${trimsuffix(each.key, ".json")}"
    namespace = var.prometheus.namespace

    labels = {
      grafana_dashboard              = "1"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    (each.key) = each.value
  }

  depends_on = [helm_release.prometheus]
}
