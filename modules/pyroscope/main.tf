locals {
  pyroscope_create_s3_secret = (
    var.pyroscope.storage.backend == "s3" &&
    var.pyroscope.storage.s3_credentials_secret == null &&
    var.pyroscope.storage.s3_access_key != ""
  )

  pyroscope_s3_secret = (
    var.pyroscope.storage.s3_credentials_secret != null ? var.pyroscope.storage.s3_credentials_secret :
    local.pyroscope_create_s3_secret ? {
      name             = "pyroscope-s3-credentials"
      access_key_field = "access-key"
      secret_key_field = "secret-key"
    } : null
  )
}

resource "kubernetes_secret" "pyroscope_s3_credentials" {
  count = local.pyroscope_create_s3_secret ? 1 : 0

  metadata {
    name      = "pyroscope-s3-credentials"
    namespace = var.pyroscope.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    "access-key" = var.pyroscope.storage.s3_access_key
    "secret-key" = var.pyroscope.storage.s3_secret_key
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.pyroscope]
}

resource "kubernetes_namespace" "pyroscope" {
  count = var.pyroscope.create_namespace ? 1 : 0

  metadata {
    name = var.pyroscope.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.pyroscope.namespace_labels)

    annotations = merge({
    }, var.pyroscope.namespace_annotations)
  }
}

resource "helm_release" "pyroscope" {
  name       = "pyroscope"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "pyroscope"
  version    = var.pyroscope.chart_version
  namespace  = var.pyroscope.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    templatefile("${path.module}/helm-values/pyroscope.yaml.tftpl", {
      storage_backend = var.pyroscope.storage.backend

      # S3
      s3_bucket          = var.pyroscope.storage.s3_bucket
      s3_region          = var.pyroscope.storage.s3_region
      # Pyroscope's S3 client does not expose a path-style config option;
      # use hostname-only endpoint format for S3-compatible services.
      s3_endpoint   = replace(replace(var.pyroscope.storage.s3_endpoint, "https://", ""), "http://", "")
      s3_insecure   = var.pyroscope.storage.s3_insecure
      s3_access_key = var.pyroscope.storage.s3_access_key
      s3_secret_key      = var.pyroscope.storage.s3_secret_key
      use_s3_secret      = local.pyroscope_s3_secret != null
      s3_secret_name     = local.pyroscope_s3_secret != null ? local.pyroscope_s3_secret.name : ""
      s3_secret_ak_field = local.pyroscope_s3_secret != null ? local.pyroscope_s3_secret.access_key_field : ""
      s3_secret_sk_field = local.pyroscope_s3_secret != null ? local.pyroscope_s3_secret.secret_key_field : ""

      # GCS
      gcs_bucket              = var.pyroscope.storage.gcs_bucket
      gcs_service_account_key = var.pyroscope.storage.gcs_service_account_key

      # Azure
      azure_storage_account     = var.pyroscope.storage.azure_storage_account
      azure_container           = var.pyroscope.storage.azure_container
      azure_storage_account_key = var.pyroscope.storage.azure_storage_account_key

      # Helm chart behaviour
      replicas = var.pyroscope.replicas

      # Resource requests/limits
      requests_cpu    = var.pyroscope.resources.requests_cpu
      requests_memory = var.pyroscope.resources.requests_memory
      limits_cpu      = var.pyroscope.resources.limits_cpu
      limits_memory   = var.pyroscope.resources.limits_memory

      service_account_annotations = var.pyroscope.service_account_annotations
    })
  ]

  depends_on = [kubernetes_namespace.pyroscope, kubernetes_secret.pyroscope_s3_credentials]
}
