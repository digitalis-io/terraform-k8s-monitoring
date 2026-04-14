locals {
  # True when the module should create a Kubernetes Secret from the supplied plain-text keys.
  mimir_create_s3_secret = (
    var.mimir.storage.backend == "s3" &&
    var.mimir.storage.s3_credentials_secret == null &&
    var.mimir.storage.s3_access_key != ""
  )

  # Resolved secret reference — external (caller-supplied) or module-managed.
  mimir_s3_secret = (
    var.mimir.storage.s3_credentials_secret != null ? var.mimir.storage.s3_credentials_secret :
    local.mimir_create_s3_secret ? {
      name             = "mimir-s3-credentials"
      access_key_field = "access-key"
      secret_key_field = "secret-key"
    } : null
  )
}

resource "kubernetes_secret" "mimir_s3_credentials" {
  count = local.mimir_create_s3_secret ? 1 : 0

  metadata {
    name      = "mimir-s3-credentials"
    namespace = var.mimir.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    "access-key" = var.mimir.storage.s3_access_key
    "secret-key" = var.mimir.storage.s3_secret_key
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.mimir]
}

resource "kubernetes_namespace" "mimir" {
  metadata {
    name = var.mimir.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.mimir.namespace_labels)

    annotations = merge({
    }, var.mimir.namespace_annotations)
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
      s3_blocks_prefix       = var.mimir.storage.s3_blocks_prefix
      s3_ruler_prefix        = var.mimir.storage.s3_ruler_prefix
      s3_alertmanager_prefix = var.mimir.storage.s3_alertmanager_prefix
      s3_region              = var.mimir.storage.s3_region
      # MinIO SDK prepends https:// itself — strip any scheme the caller may have included.
      s3_endpoint        = replace(replace(var.mimir.storage.s3_endpoint, "https://", ""), "http://", "")
      s3_insecure        = var.mimir.storage.s3_insecure
      s3_path_style      = var.mimir.storage.s3_path_style
      s3_access_key      = var.mimir.storage.s3_access_key
      s3_secret_key      = var.mimir.storage.s3_secret_key
      use_s3_secret      = local.mimir_s3_secret != null
      s3_secret_name     = local.mimir_s3_secret != null ? local.mimir_s3_secret.name : ""
      s3_secret_ak_field = local.mimir_s3_secret != null ? local.mimir_s3_secret.access_key_field : ""
      s3_secret_sk_field = local.mimir_s3_secret != null ? local.mimir_s3_secret.secret_key_field : ""

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

  depends_on = [kubernetes_namespace.mimir, kubernetes_secret.mimir_s3_credentials]
}
