resource "kubernetes_namespace" "faro_receiver" {
  count = var.faro_receiver.create_namespace ? 1 : 0

  metadata {
    name = var.faro_receiver.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.faro_receiver.namespace_labels)

    annotations = merge({
    }, var.faro_receiver.namespace_annotations)
  }
}

resource "helm_release" "faro_receiver" {
  name       = "faro-receiver"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.faro_receiver.chart_version
  namespace  = var.faro_receiver.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = compact([
    templatefile("${path.module}/helm-values/faro-receiver.yaml.tftpl", {
      controller_type = var.faro_receiver.controller_type
      replicas        = var.faro_receiver.replicas
      port            = var.faro_receiver.port

      faro_config = var.faro_receiver.faro_config

      tempo_endpoint = var.faro_receiver.tempo_endpoint
      loki_endpoint  = var.faro_receiver.loki_endpoint

      requests_cpu    = try(var.faro_receiver.resources.requests_cpu, "100m")
      requests_memory = try(var.faro_receiver.resources.requests_memory, "128Mi")
      limits_cpu      = try(var.faro_receiver.resources.limits_cpu, "500m")
      limits_memory   = try(var.faro_receiver.resources.limits_memory, "512Mi")

      ingress_enabled     = try(var.faro_receiver.ingress.enabled, false)
      ingress_host        = try(var.faro_receiver.ingress.host, "")
      ingress_class_name  = try(var.faro_receiver.ingress.class_name, "nginx")
      ingress_tls_secret  = try(var.faro_receiver.ingress.tls_secret, "")
      ingress_annotations = try(var.faro_receiver.ingress.annotations, {})

      service_account_annotations = var.faro_receiver.service_account_annotations
    }),
    var.faro_receiver.extra_values,
  ])

  depends_on = [kubernetes_namespace.faro_receiver]
}
