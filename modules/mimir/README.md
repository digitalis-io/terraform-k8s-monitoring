<div align="center">

<a href="https://digitalis.io/"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="320"/></a>

# Grafana Mimir module

**Deploys Grafana Mimir for long-term Prometheus metrics storage with S3, GCS or Azure backends and multi-tenancy support.**

</div>

Part of [terraform-k8s-monitoring](../../README.md). See the root README for full usage, examples and storage configuration guidance.

## Reference

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.17 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.36 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.mimir](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.mimir](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.mimir_s3_credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_mimir"></a> [mimir](#input\_mimir) | Grafana Mimir configuration. All fields are optional with safe defaults for a local-disk deployment. | <pre>object({<br>    chart_version         = optional(string, "5.6.0")<br>    namespace             = optional(string, "monitoring")<br>    create_namespace      = optional(bool, true)<br>    namespace_labels      = optional(map(string), {})<br>    namespace_annotations = optional(map(string), {})<br>    ingress_enabled       = optional(bool, false)<br>    ingress_host          = optional(string, "")<br>    ingress_class_name    = optional(string, "nginx")<br>    ingress_tls_secret    = optional(string, "")<br>    ingress_annotations = optional(map(string), {<br>      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"<br>    })<br>    wait             = optional(bool, true)<br>    wait_for_jobs    = optional(bool, true)<br>    timeout          = optional(number, 600)<br>    replicas         = optional(number, 1)<br>    retention_period = optional(string, "30d")<br>    # Tenant ID sent in X-Scope-OrgID header by all clients (Prometheus, Grafana).<br>    # "anonymous" works with multi-tenancy enabled and requires no extra config.<br>    # Set to a custom value to isolate metrics by team/environment.<br>    tenant_id = optional(string, "anonymous")<br><br>    resources = optional(object({<br>      requests_cpu    = optional(string, "100m")<br>      requests_memory = optional(string, "512Mi")<br>      limits_cpu      = optional(string, "2")<br>      limits_memory   = optional(string, "4Gi")<br>    }), {})<br><br>    storage = optional(object({<br>      # Which backend to use. One of: local, s3, gcs, azure.<br>      # Buckets/containers must be pre-created by the caller — this module does not create them.<br>      backend = optional(string, "local")<br><br>      # S3 — supply names of pre-existing buckets<br>      s3_blocks_bucket       = optional(string, "")<br>      s3_ruler_bucket        = optional(string, "")<br>      s3_alertmanager_bucket = optional(string, "")<br>      # Optional object key prefix — allows sharing one bucket across components.<br>      # Each storage type must use a distinct prefix (e.g. "blocks", "ruler", "alertmanager").<br>      s3_blocks_prefix       = optional(string, "")<br>      s3_ruler_prefix        = optional(string, "")<br>      s3_alertmanager_prefix = optional(string, "")<br>      s3_region              = optional(string, "")<br>      s3_endpoint            = optional(string, "")  # override for S3-compatible endpoints (Hetzner, MinIO, Ceph, etc.)<br>      s3_insecure            = optional(bool, false) # set true for HTTP-only endpoints<br>      s3_path_style          = optional(bool, false) # set true for non-AWS S3 (Hetzner, MinIO, Ceph require this)<br>      s3_access_key          = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret<br>      s3_secret_key          = optional(string, "")  # leave empty to use IRSA or s3_credentials_secret<br>      # Reference a pre-existing Kubernetes Secret containing S3 credentials.<br>      # When set, the module injects credentials as env vars rather than embedding them in Helm values.<br>      # Mutually exclusive with s3_access_key / s3_secret_key.<br>      # To share one secret across Mimir, Loki, and Tempo, pass the same name to all three modules.<br>      s3_credentials_secret = optional(object({<br>        name             = string<br>        access_key_field = optional(string, "access-key")<br>        secret_key_field = optional(string, "secret-key")<br>      }), null)<br><br>      # GCS — supply names of pre-existing buckets<br>      gcs_blocks_bucket       = optional(string, "")<br>      gcs_ruler_bucket        = optional(string, "")<br>      gcs_alertmanager_bucket = optional(string, "")<br>      # Optional object key prefix — allows sharing one bucket across components.<br>      # Mimir requires each storage type use a distinct bucket+prefix combo<br>      # (e.g. "blocks", "ruler", "alertmanager"), even on GCS.<br>      gcs_blocks_prefix       = optional(string, "")<br>      gcs_ruler_prefix        = optional(string, "")<br>      gcs_alertmanager_prefix = optional(string, "")<br>      gcs_service_account_key = optional(string, "") # leave empty to use Workload Identity<br><br>      # Azure — supply names of pre-existing containers<br>      azure_storage_account        = optional(string, "")<br>      azure_blocks_container       = optional(string, "")<br>      azure_ruler_container        = optional(string, "")<br>      azure_alertmanager_container = optional(string, "")<br>      azure_storage_account_key    = optional(string, "") # leave empty to use Workload Identity<br>    }), {})<br><br>    # Annotations to add to the Mimir ServiceAccount.<br>    # Use this for IRSA, GKE Workload Identity, or Azure Workload Identity.<br>    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.<br>    # Examples:<br>    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/mimir" }<br>    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "mimir@project.iam.gserviceaccount.com" }<br>    service_account_annotations = optional(map(string), {})<br><br>    # Raw Helm values YAML, applied on top of this module's generated values<br>    # (e.g. mimir.structuredConfig.limits, per-component resources/replicas).<br>    # See the mimir-distributed chart's values.yaml for available keys.<br>    extra_values = optional(string, "")<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_release_name"></a> [helm\_release\_name](#output\_helm\_release\_name) | Name of the Helm release. |
| <a name="output_helm_release_version"></a> [helm\_release\_version](#output\_helm\_release\_version) | Deployed chart version. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace where Mimir is deployed. |
| <a name="output_query_frontend_endpoint"></a> [query\_frontend\_endpoint](#output\_query\_frontend\_endpoint) | Grafana datasource URL (Prometheus-compatible) for this Mimir instance. |
| <a name="output_remote_write_endpoint"></a> [remote\_write\_endpoint](#output\_remote\_write\_endpoint) | Prometheus remote\_write URL for this Mimir instance. |
| <a name="output_tenant_id"></a> [tenant\_id](#output\_tenant\_id) | Mimir tenant ID. Pass as X-Scope-OrgID header in remote\_write and Grafana datasource config. |

---

Maintained by [Digitalis.io](https://digitalis.io) — support at [digitalis.io/contact](https://digitalis.io/contact).
