variable "mimir" {
  description = "Grafana Mimir configuration. All fields are optional with safe defaults for a local-disk deployment."
  type = object({
    chart_version = optional(string, "6.1.0")
    # Helm repo for the mimir-distributed chart. Grafana froze the
    # https://grafana.github.io/helm-charts HTTP repo; the chart is now published
    # as OCI on ghcr.io. Public registry — no login required.
    chart_repository = optional(string, "oci://ghcr.io/grafana/helm-charts")

    # Kafka ingest-storage architecture (Mimir 3.x write path via Kafka).
    # https://grafana.com/docs/mimir/latest/configure/configure-kafka-backend/
    # Default off → classic ingester path (single-replica friendly). The
    # mimir-distributed 6.x chart defaults this ON with a bundled demo Kafka and
    # zone-aware ingesters; the module pins the architecture explicitly so it
    # never flips on a chart bump.
    #   enabled=true, address="" → deploy the chart's bundled demo Kafka.
    #   enabled=true, address set → use an external broker (bring-your-own).
    kafka_ingest = optional(object({
      enabled    = optional(bool, false)
      address    = optional(string, "") # external bootstrap host:port; "" uses the bundled demo Kafka
      topic      = optional(string, "") # "" keeps the chart default (mimir-ingest)
      partitions = optional(number, 0)  # auto_create_topic_default_partitions; must be >= max ingester replicas per zone. 0 keeps chart default
    }), {})

    namespace             = optional(string, "monitoring")
    create_namespace      = optional(bool, true)
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    ingress_enabled       = optional(bool, false)
    ingress_host          = optional(string, "")
    ingress_class_name    = optional(string, "nginx")
    ingress_tls_secret    = optional(string, "")
    ingress_annotations = optional(map(string), {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    })
    wait             = optional(bool, true)
    wait_for_jobs    = optional(bool, true)
    timeout          = optional(number, 600)
    replicas         = optional(number, 1)
    retention_period = optional(string, "30d")
    # Tenant ID sent in X-Scope-OrgID header by all clients (Prometheus, Grafana).
    # "anonymous" works with multi-tenancy enabled and requires no extra config.
    # Set to a custom value to isolate metrics by team/environment.
    tenant_id = optional(string, "anonymous")

    resources = optional(object({
      requests_cpu    = optional(string, "100m")
      requests_memory = optional(string, "512Mi")
      limits_cpu      = optional(string, "2")
      limits_memory   = optional(string, "4Gi")
    }), {})

    storage = optional(object({
      # Which backend to use. One of: local, s3, gcs, azure.
      # Buckets/containers must be pre-created by the caller — this module does not create them.
      backend = optional(string, "local")

      # S3 — supply names of pre-existing buckets
      s3_blocks_bucket       = optional(string, "")
      s3_ruler_bucket        = optional(string, "")
      s3_alertmanager_bucket = optional(string, "")
      # Optional object key prefix — allows sharing one bucket across components.
      # Each storage type must use a distinct prefix (e.g. "blocks", "ruler", "alertmanager").
      s3_blocks_prefix       = optional(string, "")
      s3_ruler_prefix        = optional(string, "")
      s3_alertmanager_prefix = optional(string, "")
      s3_region              = optional(string, "")
      s3_endpoint            = optional(string, "")  # override for S3-compatible endpoints (Hetzner, MinIO, Ceph, etc.)
      s3_insecure            = optional(bool, false) # set true for HTTP-only endpoints
      s3_path_style          = optional(bool, false) # set true for non-AWS S3 (Hetzner, MinIO, Ceph require this)
      s3_access_key          = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret
      s3_secret_key          = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret
      # Reference a pre-existing Kubernetes Secret containing S3 credentials.
      # When set, the module injects credentials as env vars rather than embedding them in Helm values.
      # Mutually exclusive with s3_access_key / s3_secret_key.
      # To share one secret across Mimir, Loki, and Tempo, pass the same name to all three modules.
      s3_credentials_secret = optional(object({
        name             = string
        access_key_field = optional(string, "access-key")
        secret_key_field = optional(string, "secret-key")
      }), null)

      # GCS — supply names of pre-existing buckets
      gcs_blocks_bucket       = optional(string, "")
      gcs_ruler_bucket        = optional(string, "")
      gcs_alertmanager_bucket = optional(string, "")
      # Optional object key prefix — allows sharing one bucket across components.
      # Mimir requires each storage type use a distinct bucket+prefix combo
      # (e.g. "blocks", "ruler", "alertmanager"), even on GCS.
      gcs_blocks_prefix       = optional(string, "")
      gcs_ruler_prefix        = optional(string, "")
      gcs_alertmanager_prefix = optional(string, "")
      gcs_service_account_key = optional(string, "") # leave empty to use Workload Identity

      # Azure — supply names of pre-existing containers
      azure_storage_account        = optional(string, "")
      azure_blocks_container       = optional(string, "")
      azure_ruler_container        = optional(string, "")
      azure_alertmanager_container = optional(string, "")
      azure_storage_account_key    = optional(string, "") # leave empty to use Workload Identity
    }), {})

    # Annotations to add to the Mimir ServiceAccount.
    # Use this for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/mimir" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "mimir@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})

    # Raw Helm values YAML, applied on top of this module's generated values
    # (e.g. mimir.structuredConfig.limits, per-component resources/replicas).
    # See the mimir-distributed chart's values.yaml for available keys.
    extra_values = optional(string, "")
  })
  default = {}

  validation {
    condition = !(var.mimir.ingress_enabled && (
      var.mimir.ingress_host == "" ||
      !can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.mimir.ingress_host))
    ))
    error_message = "ingress_host must be a valid RFC 1123 hostname (e.g. mimir.example.com) when ingress_enabled is true."
  }

  validation {
    condition     = contains(["local", "s3", "gcs", "azure"], var.mimir.storage.backend)
    error_message = "storage.backend must be one of: local, s3, gcs, azure."
  }

  validation {
    condition = !(var.mimir.storage.backend == "s3" && (
      var.mimir.storage.s3_blocks_bucket == "" ||
      var.mimir.storage.s3_ruler_bucket == "" ||
      var.mimir.storage.s3_alertmanager_bucket == "" ||
      var.mimir.storage.s3_region == ""
    ))
    error_message = "When storage.backend is 's3', s3_blocks_bucket, s3_ruler_bucket, s3_alertmanager_bucket, and s3_region are required."
  }

  validation {
    condition = !(var.mimir.storage.backend == "gcs" && (
      var.mimir.storage.gcs_blocks_bucket == "" ||
      var.mimir.storage.gcs_ruler_bucket == "" ||
      var.mimir.storage.gcs_alertmanager_bucket == ""
    ))
    error_message = "When storage.backend is 'gcs', gcs_blocks_bucket, gcs_ruler_bucket, and gcs_alertmanager_bucket are required."
  }

  validation {
    condition = !(
      try(var.mimir.storage.s3_credentials_secret, null) != null &&
      (try(var.mimir.storage.s3_access_key, "") != "" || try(var.mimir.storage.s3_secret_key, "") != "")
    )
    error_message = "storage.s3_credentials_secret is mutually exclusive with storage.s3_access_key / storage.s3_secret_key."
  }

  validation {
    condition = !(var.mimir.storage.backend == "azure" && (
      var.mimir.storage.azure_storage_account == "" ||
      var.mimir.storage.azure_blocks_container == "" ||
      var.mimir.storage.azure_ruler_container == "" ||
      var.mimir.storage.azure_alertmanager_container == ""
    ))
    error_message = "When storage.backend is 'azure', azure_storage_account and all three azure container names are required."
  }
}
