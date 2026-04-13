resource "kubernetes_namespace" "prometheus" {
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
  namespace  = kubernetes_namespace.prometheus.metadata[0].name

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
      ingress_enabled      = var.prometheus.ingress_enabled
      ingress_host         = var.prometheus.ingress_host
      ingress_class_name   = var.prometheus.ingress_class_name
      ingress_tls_secret   = var.prometheus.ingress_tls_secret != "" ? var.prometheus.ingress_tls_secret : "${var.prometheus.namespace}-grafana-tls"
      ingress_annotations  = var.prometheus.ingress_annotations
      namespace            = var.prometheus.namespace

      mimir_remote_write_url = var.prometheus.mimir_remote_write_url
      mimir_datasource_url   = var.prometheus.mimir_datasource_url

      requests_cpu    = var.prometheus.resources.requests_cpu
      requests_memory = var.prometheus.resources.requests_memory
      limits_cpu      = var.prometheus.resources.limits_cpu
      limits_memory   = var.prometheus.resources.limits_memory
    })
  ]

  depends_on = [kubernetes_namespace.prometheus]
}
