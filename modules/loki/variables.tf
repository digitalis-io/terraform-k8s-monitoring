variable "loki" {
  description = "Grafana Loki configuration. All fields are optional with safe defaults for a local-disk deployment."
  type = object({
    chart_version = optional(string, "7.1.0")
    # Helm repo for the loki chart. The OSS chart moved to the grafana-community
    # fork (2026-03, forked at chart 6.55.0); Loki >= 3.7 is ONLY published there
    # (grafana.github.io/helm-charts tops out at 3.6.x). Point here + set a
    # community chart_version (e.g. 18.5.0 = Loki 3.7.3) to run a newer Loki.
    chart_repository      = optional(string, "https://grafana.github.io/helm-charts")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    # "single-binary" — all components in one process (default, good for dev/blog)
    # "scalable"      — separate read, write, backend replica sets (SimpleScalable mode)
    deployment_mode  = optional(string, "single-binary")
    replicas         = optional(number, 1)
    retention_period = optional(string, "744h") # 31 days

    # Helm release wait behaviour.
    wait          = optional(bool, true)
    wait_for_jobs = optional(bool, true)
    timeout       = optional(number, 600)

    resources = optional(object({
      requests_cpu    = optional(string, "100m")
      requests_memory = optional(string, "256Mi")
      limits_cpu      = optional(string, "2")
      limits_memory   = optional(string, "2Gi")
    }), {})

    storage = optional(object({
      # Which backend to use. One of: local, s3, gcs, azure.
      # Buckets/containers must be pre-created by the caller — this module does not create them.
      backend = optional(string, "local")

      # S3 — supply names of pre-existing buckets
      s3_chunks_bucket = optional(string, "")
      s3_ruler_bucket  = optional(string, "")
      s3_region        = optional(string, "")
      s3_endpoint      = optional(string, "")  # override for S3-compatible endpoints (Hetzner, MinIO, Ceph, etc.)
      s3_insecure      = optional(bool, false) # set true for HTTP-only endpoints
      s3_path_style    = optional(bool, false) # set true for non-AWS S3 (Hetzner, MinIO, Ceph require this)
      s3_access_key    = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret
      s3_secret_key    = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret
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
      gcs_chunks_bucket       = optional(string, "")
      gcs_ruler_bucket        = optional(string, "")
      gcs_service_account_key = optional(string, "") # leave empty to use Workload Identity

      # Azure — supply names of pre-existing containers
      azure_storage_account     = optional(string, "")
      azure_chunks_container    = optional(string, "")
      azure_ruler_container     = optional(string, "")
      azure_storage_account_key = optional(string, "") # leave empty to use Workload Identity
    }), {})

    # Annotations to add to the Loki ServiceAccount.
    # Use this for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/loki" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "loki@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})

    # Raw Helm values YAML, applied on top of this module's generated values
    # (e.g. loki.limits_config, singleBinary/write/read resources or replicas).
    # See the loki chart's values.yaml for available keys.
    extra_values = optional(string, "")
  })
  default = {}

  validation {
    condition     = contains(["single-binary", "scalable"], var.loki.deployment_mode)
    error_message = "deployment_mode must be one of: single-binary, scalable."
  }

  validation {
    condition     = contains(["local", "s3", "gcs", "azure"], var.loki.storage.backend)
    error_message = "storage.backend must be one of: local, s3, gcs, azure."
  }

  validation {
    condition = !(var.loki.storage.backend == "s3" && (
      var.loki.storage.s3_chunks_bucket == "" ||
      var.loki.storage.s3_ruler_bucket == "" ||
      var.loki.storage.s3_region == ""
    ))
    error_message = "When storage.backend is 's3', s3_chunks_bucket, s3_ruler_bucket, and s3_region are required."
  }

  validation {
    condition = !(var.loki.storage.backend == "gcs" && (
      var.loki.storage.gcs_chunks_bucket == "" ||
      var.loki.storage.gcs_ruler_bucket == ""
    ))
    error_message = "When storage.backend is 'gcs', gcs_chunks_bucket and gcs_ruler_bucket are required."
  }

  validation {
    condition = !(var.loki.storage.backend == "azure" && (
      var.loki.storage.azure_storage_account == "" ||
      var.loki.storage.azure_chunks_container == "" ||
      var.loki.storage.azure_ruler_container == ""
    ))
    error_message = "When storage.backend is 'azure', azure_storage_account and both azure container names are required."
  }

  validation {
    condition = !(
      try(var.loki.storage.s3_credentials_secret, null) != null &&
      (try(var.loki.storage.s3_access_key, "") != "" || try(var.loki.storage.s3_secret_key, "") != "")
    )
    error_message = "storage.s3_credentials_secret is mutually exclusive with storage.s3_access_key/s3_secret_key. Set only one method for supplying S3 credentials."
  }
}
