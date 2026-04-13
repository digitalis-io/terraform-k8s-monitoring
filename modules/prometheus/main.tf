resource "kubernetes_namespace" "prometheus" {
  count = var.prometheus.create_namespace ? 1 : 0

  metadata {
    name = var.prometheus.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }

    annotations = {
      "linkerd.io/inject" = "disabled"
    }
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
    templatefile("${path.module}/helm-values/prometheus.yaml.tftpl", {
      retention            = var.prometheus.retention
      storage_size         = var.prometheus.storage_size
      storage_class        = var.prometheus.storage_class
      grafana_enabled      = var.prometheus.grafana_enabled
      alertmanager_enabled = var.prometheus.alertmanager_enabled
      namespace            = var.prometheus.namespace

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

      loki_datasource_url  = var.prometheus.loki_datasource_url
      tempo_datasource_url = var.prometheus.tempo_datasource_url

      grafana_dashboard_imports = var.prometheus.grafana_dashboard_imports

      requests_cpu    = var.prometheus.resources.requests_cpu
      requests_memory = var.prometheus.resources.requests_memory
      limits_cpu      = var.prometheus.resources.limits_cpu
      limits_memory   = var.prometheus.resources.limits_memory
    })
  ]

  depends_on = [kubernetes_namespace.prometheus]
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
    "${each.key}" = each.value
  }

  depends_on = [helm_release.prometheus]
}
