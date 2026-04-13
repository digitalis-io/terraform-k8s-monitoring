resource "kubernetes_namespace" "tempo" {
  count = var.tempo.create_namespace ? 1 : 0

  metadata {
    name = var.tempo.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }

    annotations = {
      "linkerd.io/inject" = "disabled"
    }
  }
}

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo-distributed"
  version    = var.tempo.chart_version
  namespace  = var.tempo.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    templatefile("${path.module}/helm-values/tempo.yaml.tftpl", {
      storage_backend = var.tempo.storage.backend

      # S3
      s3_bucket     = var.tempo.storage.s3_bucket
      s3_region     = var.tempo.storage.s3_region
      s3_endpoint   = var.tempo.storage.s3_endpoint
      s3_access_key = var.tempo.storage.s3_access_key
      s3_secret_key = var.tempo.storage.s3_secret_key

      # GCS
      gcs_bucket              = var.tempo.storage.gcs_bucket
      gcs_service_account_key = var.tempo.storage.gcs_service_account_key

      # Azure
      azure_storage_account     = var.tempo.storage.azure_storage_account
      azure_container           = var.tempo.storage.azure_container
      azure_storage_account_key = var.tempo.storage.azure_storage_account_key

      # Helm chart behaviour
      deployment_mode = var.tempo.deployment_mode
      replicas        = var.tempo.replicas
      retention       = var.tempo.retention

      # Resource requests/limits
      requests_cpu    = var.tempo.resources.requests_cpu
      requests_memory = var.tempo.resources.requests_memory
      limits_cpu      = var.tempo.resources.limits_cpu
      limits_memory   = var.tempo.resources.limits_memory

      service_account_annotations = var.tempo.service_account_annotations
    })
  ]

  depends_on = [kubernetes_namespace.tempo]
}
