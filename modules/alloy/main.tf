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
  name       = "alloy"
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

      # Sibling endpoints (used in built-in config when alloy_config = "")
      loki_endpoint      = var.alloy.loki_endpoint
      tempo_endpoint     = var.alloy.tempo_endpoint
      mimir_endpoint     = var.alloy.mimir_endpoint
      mimir_tenant_id    = var.alloy.mimir_tenant_id
      pyroscope_endpoint = var.alloy.pyroscope_endpoint
      otel_grpc_endpoint = var.alloy.otel_grpc_endpoint

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
