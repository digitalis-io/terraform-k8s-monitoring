variable "pyroscope" {
  description = "Grafana Pyroscope configuration. All fields are optional with safe defaults for a local-disk deployment."
  type = object({
    chart_version         = optional(string, "1.20.3")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)

    replicas = optional(number, 1)

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
      s3_access_key = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret
      s3_secret_key = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret
      # Reference a pre-existing Kubernetes Secret containing S3 credentials.
      # When set, the module injects credentials as env vars rather than embedding them in Helm values.
      # Mutually exclusive with s3_access_key / s3_secret_key.
      # To share one secret across modules, pass the same name to all storage modules.
      s3_credentials_secret = optional(object({
        name             = string
        access_key_field = optional(string, "access-key")
        secret_key_field = optional(string, "secret-key")
      }), null)

      # GCS — supply name of a pre-existing bucket
      gcs_bucket              = optional(string, "")
      gcs_service_account_key = optional(string, "") # leave empty to use Workload Identity

      # Azure — supply name of a pre-existing container
      azure_storage_account     = optional(string, "")
      azure_container           = optional(string, "")
      azure_storage_account_key = optional(string, "") # leave empty to use Workload Identity
    }), {})

    # Annotations to add to the Pyroscope ServiceAccount.
    # Use this for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/pyroscope" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "pyroscope@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})
  })
  default = {}

  validation {
    condition     = contains(["local", "s3", "gcs", "azure"], var.pyroscope.storage.backend)
    error_message = "storage.backend must be one of: local, s3, gcs, azure."
  }

  validation {
    condition = !(var.pyroscope.storage.backend == "s3" && (
      var.pyroscope.storage.s3_bucket == "" ||
      var.pyroscope.storage.s3_region == ""
    ))
    error_message = "When storage.backend is 's3', s3_bucket and s3_region are required."
  }

  validation {
    condition = !(var.pyroscope.storage.backend == "gcs" && (
      var.pyroscope.storage.gcs_bucket == ""
    ))
    error_message = "When storage.backend is 'gcs', gcs_bucket is required."
  }

  validation {
    condition = !(var.pyroscope.storage.backend == "azure" && (
      var.pyroscope.storage.azure_storage_account == "" ||
      var.pyroscope.storage.azure_container == ""
    ))
    error_message = "When storage.backend is 'azure', azure_storage_account and azure_container are required."
  }
}
