resource "kubernetes_namespace" "loki" {
  count = var.loki.create_namespace ? 1 : 0

  metadata {
    name = var.loki.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }

    annotations = {
      "linkerd.io/inject" = "disabled"
    }
  }
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki.chart_version
  namespace  = var.loki.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    templatefile("${path.module}/helm-values/loki.yaml.tftpl", {
      storage_backend = var.loki.storage.backend

      # S3
      s3_chunks_bucket = var.loki.storage.s3_chunks_bucket
      s3_ruler_bucket  = var.loki.storage.s3_ruler_bucket
      s3_region        = var.loki.storage.s3_region
      s3_endpoint      = var.loki.storage.s3_endpoint
      s3_access_key    = var.loki.storage.s3_access_key
      s3_secret_key    = var.loki.storage.s3_secret_key

      # GCS
      gcs_chunks_bucket       = var.loki.storage.gcs_chunks_bucket
      gcs_ruler_bucket        = var.loki.storage.gcs_ruler_bucket
      gcs_service_account_key = var.loki.storage.gcs_service_account_key

      # Azure
      azure_storage_account     = var.loki.storage.azure_storage_account
      azure_chunks_container    = var.loki.storage.azure_chunks_container
      azure_ruler_container     = var.loki.storage.azure_ruler_container
      azure_storage_account_key = var.loki.storage.azure_storage_account_key

      # Helm chart behaviour
      deployment_mode  = var.loki.deployment_mode
      replicas         = var.loki.replicas
      retention_period = var.loki.retention_period

      # Resource requests/limits
      requests_cpu    = var.loki.resources.requests_cpu
      requests_memory = var.loki.resources.requests_memory
      limits_cpu      = var.loki.resources.limits_cpu
      limits_memory   = var.loki.resources.limits_memory

      service_account_annotations = var.loki.service_account_annotations
    })
  ]

  depends_on = [kubernetes_namespace.loki]
}
