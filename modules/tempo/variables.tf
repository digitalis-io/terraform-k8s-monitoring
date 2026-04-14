variable "tempo" {
  description = "Grafana Tempo configuration. All fields are optional with safe defaults for a local-disk deployment."
  type = object({
    chart_version    = optional(string, "1.40.0")
    namespace        = optional(string, "monitoring")
    create_namespace = optional(bool, true)
    # "monolithic"   — single tempo process (default, good for dev/blog)
    # "distributed"  — separate ingester, distributor, querier, compactor, etc.
    deployment_mode = optional(string, "monolithic")
    replicas        = optional(number, 1)
    retention       = optional(string, "720h") # 30 days

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

      # S3 — supply name of a pre-existing bucket
      s3_bucket     = optional(string, "")
      s3_region     = optional(string, "")
      s3_endpoint   = optional(string, "")  # override for S3-compatible endpoints (Hetzner, MinIO, Ceph, etc.)
      s3_insecure   = optional(bool, false) # set true for HTTP-only endpoints
      s3_path_style = optional(bool, false) # set true for non-AWS S3 (Hetzner, MinIO, Ceph require this)
      s3_access_key = optional(string, "")  # leave empty to use IRSA
      s3_secret_key = optional(string, "")  # leave empty to use IRSA

      # GCS — supply name of a pre-existing bucket
      gcs_bucket              = optional(string, "")
      gcs_service_account_key = optional(string, "") # leave empty to use Workload Identity

      # Azure — supply name of a pre-existing container
      azure_storage_account     = optional(string, "")
      azure_container           = optional(string, "")
      azure_storage_account_key = optional(string, "") # leave empty to use Workload Identity
    }), {})

    # Annotations to add to the Tempo ServiceAccount.
    # Use this for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/tempo" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "tempo@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})
  })
  default = {}

  validation {
    condition     = contains(["monolithic", "distributed"], var.tempo.deployment_mode)
    error_message = "deployment_mode must be one of: monolithic, distributed."
  }

  validation {
    condition     = contains(["local", "s3", "gcs", "azure"], var.tempo.storage.backend)
    error_message = "storage.backend must be one of: local, s3, gcs, azure."
  }

  validation {
    condition = !(var.tempo.storage.backend == "s3" && (
      var.tempo.storage.s3_bucket == "" ||
      var.tempo.storage.s3_region == ""
    ))
    error_message = "When storage.backend is 's3', s3_bucket and s3_region are required."
  }

  validation {
    condition = !(var.tempo.storage.backend == "gcs" && (
      var.tempo.storage.gcs_bucket == ""
    ))
    error_message = "When storage.backend is 'gcs', gcs_bucket is required."
  }

  validation {
    condition = !(var.tempo.storage.backend == "azure" && (
      var.tempo.storage.azure_storage_account == "" ||
      var.tempo.storage.azure_container == ""
    ))
    error_message = "When storage.backend is 'azure', azure_storage_account and azure_container are required."
  }
}
