locals {
  traces_exporters  = var.otel.tempo_endpoint != "" ? "[otlp/tempo]" : "[debug]"
  metrics_exporters = var.otel.mimir_endpoint != "" ? "[prometheusremotewrite]" : "[debug]"
  logs_exporters    = var.otel.loki_endpoint != "" ? "[otlphttp/loki]" : "[debug]"
  logs_receivers    = var.otel.mode == "daemonset" ? "[otlp, filelog]" : "[otlp]"
}

resource "kubernetes_namespace" "otel" {
  count = var.otel.create_namespace ? 1 : 0

  metadata {
    name = var.otel.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.otel.namespace_labels)

    annotations = merge({
    }, var.otel.namespace_annotations)
  }
}

resource "helm_release" "otel" {
  name       = "otel"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.otel.chart_version
  namespace  = var.otel.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    templatefile("${path.module}/helm-values/otel-collector.yaml.tftpl", {
      mode = var.otel.mode

      # Image
      image_repository  = var.otel.image.repository
      image_tag         = var.otel.image.tag
      image_pull_policy = var.otel.image.pull_policy

      # Exporter endpoints
      tempo_endpoint = var.otel.tempo_endpoint
      mimir_endpoint = var.otel.mimir_endpoint
      loki_endpoint  = var.otel.loki_endpoint

      # Pre-computed pipeline lists
      traces_exporters  = local.traces_exporters
      metrics_exporters = local.metrics_exporters
      logs_exporters    = local.logs_exporters
      logs_receivers    = local.logs_receivers

      # Resource requests/limits
      requests_cpu    = var.otel.resources.requests_cpu
      requests_memory = var.otel.resources.requests_memory
      limits_cpu      = var.otel.resources.limits_cpu
      limits_memory   = var.otel.resources.limits_memory

      service_account_annotations = var.otel.service_account_annotations
    })
  ]

  depends_on = [kubernetes_namespace.otel]
}
