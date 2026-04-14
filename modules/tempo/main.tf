locals {
  tempo_create_s3_secret = (
    var.tempo.storage.backend == "s3" &&
    var.tempo.storage.s3_credentials_secret == null &&
    var.tempo.storage.s3_access_key != ""
  )

  tempo_s3_secret = (
    var.tempo.storage.s3_credentials_secret != null ? var.tempo.storage.s3_credentials_secret :
    local.tempo_create_s3_secret ? {
      name             = "tempo-s3-credentials"
      access_key_field = "access-key"
      secret_key_field = "secret-key"
    } : null
  )
}

resource "kubernetes_secret" "tempo_s3_credentials" {
  count = local.tempo_create_s3_secret ? 1 : 0

  metadata {
    name      = "tempo-s3-credentials"
    namespace = var.tempo.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    "access-key" = var.tempo.storage.s3_access_key
    "secret-key" = var.tempo.storage.s3_secret_key
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.tempo]
}

resource "kubernetes_namespace" "tempo" {
  count = var.tempo.create_namespace ? 1 : 0

  metadata {
    name = var.tempo.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.tempo.namespace_labels)

    annotations = merge({
    }, var.tempo.namespace_annotations)
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
      s3_bucket          = var.tempo.storage.s3_bucket
      s3_region          = var.tempo.storage.s3_region
      s3_endpoint        = replace(replace(var.tempo.storage.s3_endpoint, "https://", ""), "http://", "")
      s3_insecure        = var.tempo.storage.s3_insecure
      s3_path_style      = var.tempo.storage.s3_path_style
      s3_access_key      = var.tempo.storage.s3_access_key
      s3_secret_key      = var.tempo.storage.s3_secret_key
      use_s3_secret      = local.tempo_s3_secret != null
      s3_secret_name     = local.tempo_s3_secret != null ? local.tempo_s3_secret.name : ""
      s3_secret_ak_field = local.tempo_s3_secret != null ? local.tempo_s3_secret.access_key_field : ""
      s3_secret_sk_field = local.tempo_s3_secret != null ? local.tempo_s3_secret.secret_key_field : ""

      # GCS
      gcs_bucket              = var.tempo.storage.gcs_bucket
      gcs_service_account_key = var.tempo.storage.gcs_service_account_key

      # Azure
      azure_storage_account     = var.tempo.storage.azure_storage_account
      azure_container           = var.tempo.storage.azure_container
      azure_storage_account_key = var.tempo.storage.azure_storage_account_key

      # Helm chart behaviour
      replicas  = var.tempo.replicas
      retention = var.tempo.retention

      # Resource requests/limits
      requests_cpu    = var.tempo.resources.requests_cpu
      requests_memory = var.tempo.resources.requests_memory
      limits_cpu      = var.tempo.resources.limits_cpu
      limits_memory   = var.tempo.resources.limits_memory

      service_account_annotations = var.tempo.service_account_annotations
    })
  ]

  depends_on = [kubernetes_namespace.tempo, kubernetes_secret.tempo_s3_credentials]
}
