resource "kubernetes_namespace" "mimir" {
  metadata {
    name = var.mimir.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }

    annotations = {
      "linkerd.io/inject" = "disabled"
    }
  }
}

resource "helm_release" "mimir" {
  name       = "mimir"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "mimir-distributed"
  version    = var.mimir.chart_version
  namespace  = kubernetes_namespace.mimir.metadata[0].name

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    templatefile("${path.module}/helm-values/mimir.yaml.tftpl", {
      storage_backend = var.mimir.storage.backend

      # S3
      s3_blocks_bucket       = var.mimir.storage.s3_blocks_bucket
      s3_ruler_bucket        = var.mimir.storage.s3_ruler_bucket
      s3_alertmanager_bucket = var.mimir.storage.s3_alertmanager_bucket
      s3_region              = var.mimir.storage.s3_region
      s3_endpoint            = var.mimir.storage.s3_endpoint
      s3_access_key          = var.mimir.storage.s3_access_key
      s3_secret_key          = var.mimir.storage.s3_secret_key

      # GCS
      gcs_blocks_bucket       = var.mimir.storage.gcs_blocks_bucket
      gcs_ruler_bucket        = var.mimir.storage.gcs_ruler_bucket
      gcs_alertmanager_bucket = var.mimir.storage.gcs_alertmanager_bucket

      # Azure
      azure_storage_account        = var.mimir.storage.azure_storage_account
      azure_blocks_container       = var.mimir.storage.azure_blocks_container
      azure_ruler_container        = var.mimir.storage.azure_ruler_container
      azure_alertmanager_container = var.mimir.storage.azure_alertmanager_container
      azure_storage_account_key    = var.mimir.storage.azure_storage_account_key

      # Helm chart behaviour
      ingress_enabled     = var.mimir.ingress_enabled
      ingress_host        = var.mimir.ingress_host
      ingress_class_name  = var.mimir.ingress_class_name
      ingress_tls_secret  = var.mimir.ingress_tls_secret != "" ? var.mimir.ingress_tls_secret : "${var.mimir.namespace}-mimir-tls"
      ingress_annotations = var.mimir.ingress_annotations
      replicas            = var.mimir.replicas
      retention_period    = var.mimir.retention_period

      # Resource requests/limits
      requests_cpu    = var.mimir.resources.requests_cpu
      requests_memory = var.mimir.resources.requests_memory
      limits_cpu      = var.mimir.resources.limits_cpu
      limits_memory   = var.mimir.resources.limits_memory

      service_account_annotations = var.mimir.service_account_annotations
    })
  ]

  depends_on = [kubernetes_namespace.mimir]
}
