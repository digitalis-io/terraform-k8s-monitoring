locals {
  faro_enabled = try(var.alloy.faro_receiver.enabled, false)
  faro_port    = try(var.alloy.faro_receiver.port, 12347)

  # OTLP-receiver branch (alloy_config = ""): fan out each signal to every
  # configured destination. mimir/loki/tempo and otel_grpc_endpoint are
  # independent — set one, the other, or both for a dual-write.
  _metrics_outputs = compact([
    var.alloy.mimir_endpoint != "" ? "otelcol.exporter.prometheus.default.input" : "",
    var.alloy.otel_grpc_endpoint != "" ? "otelcol.exporter.otlp.upstream.input" : "",
  ])
  _logs_outputs = compact([
    var.alloy.loki_endpoint != "" ? "otelcol.exporter.loki.default.input" : "",
    var.alloy.otel_grpc_endpoint != "" ? "otelcol.exporter.otlp.upstream.input" : "",
  ])
  _traces_outputs = compact([
    var.alloy.tempo_endpoint != "" ? "otelcol.exporter.otlp.tempo.input" : "",
    var.alloy.otel_grpc_endpoint != "" ? "otelcol.exporter.otlp.upstream.input" : "",
  ])

  metrics_outputs = length(local._metrics_outputs) > 0 ? join(", ", local._metrics_outputs) : "otelcol.exporter.debug.default.input"
  logs_outputs    = length(local._logs_outputs) > 0 ? join(", ", local._logs_outputs) : "otelcol.exporter.debug.default.input"
  traces_outputs  = length(local._traces_outputs) > 0 ? join(", ", local._traces_outputs) : "otelcol.exporter.debug.default.input"
}

resource "kubernetes_namespace" "alloy" {
  count = var.alloy.create_namespace ? 1 : 0

  metadata {
    name = var.alloy.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.alloy.namespace_labels)

    annotations = merge({
    }, var.alloy.namespace_annotations)
  }
}

resource "helm_release" "alloy" {
  name       = var.alloy.release_name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy.chart_version
  namespace  = var.alloy.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = compact([
    templatefile("${path.module}/helm-values/alloy.yaml.tftpl", {
      controller_type = var.alloy.controller_type
      replicas        = var.alloy.replicas

      # Alloy pipeline config
      alloy_config = var.alloy.alloy_config
      faro_enabled = local.faro_enabled
      faro_port    = local.faro_port

      # Ports
      extra_ports = length(var.alloy.extra_ports) > 0 ? var.alloy.extra_ports : (
        local.faro_enabled
        ? [{ name = "faro-http", port = local.faro_port, target_port = local.faro_port, protocol = "TCP" }]
        : [
          { name = "otlp-grpc", port = 4317, target_port = 4317, protocol = "TCP" },
          { name = "otlp-http", port = 4318, target_port = 4318, protocol = "TCP" },
        ]
      )

      # Sibling endpoints (used in built-in config when alloy_config = "")
      loki_endpoint      = var.alloy.loki_endpoint
      tempo_endpoint     = var.alloy.tempo_endpoint
      mimir_endpoint     = var.alloy.mimir_endpoint
      mimir_tenant_id    = var.alloy.mimir_tenant_id
      pyroscope_endpoint = var.alloy.pyroscope_endpoint
      otel_grpc_endpoint = var.alloy.otel_grpc_endpoint

      # Pre-computed fan-out lists for the OTLP-receiver branch
      metrics_outputs = local.metrics_outputs
      logs_outputs    = local.logs_outputs
      traces_outputs  = local.traces_outputs

      # Persistence
      persistence_enabled       = try(var.alloy.persistence.enabled, false)
      persistence_storage_class = try(var.alloy.persistence.storage_class, "")
      persistence_size          = try(var.alloy.persistence.size, "10Gi")
      persistence_access_mode   = try(var.alloy.persistence.access_mode, "ReadWriteOnce")

      # Resources
      requests_cpu    = try(var.alloy.resources.requests_cpu, "100m")
      requests_memory = try(var.alloy.resources.requests_memory, "128Mi")
      limits_cpu      = try(var.alloy.resources.limits_cpu, "500m")
      limits_memory   = try(var.alloy.resources.limits_memory, "512Mi")

      # Ingress
      ingress_enabled     = try(var.alloy.ingress.enabled, false)
      ingress_host        = try(var.alloy.ingress.host, "")
      ingress_class_name  = try(var.alloy.ingress.class_name, "nginx")
      ingress_tls_secret  = try(var.alloy.ingress.tls_secret, "")
      ingress_annotations = try(var.alloy.ingress.annotations, {})

      service_account_annotations = var.alloy.service_account_annotations
    }),
    var.alloy.extra_values,
  ])

  depends_on = [kubernetes_namespace.alloy]
}
