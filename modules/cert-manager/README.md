<div align="center">

<a href="https://digitalis.io/"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="320"/></a>

# cert-manager module

**Deploys cert-manager and a configurable ClusterIssuer (self-signed, ACME/Let's Encrypt, or an existing CA) for ingress TLS.**

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
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [terraform_data.cluster_issuer](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cert_manager"></a> [cert\_manager](#input\_cert\_manager) | cert-manager configuration. | <pre>object({<br>    chart_version         = optional(string, "v1.19.1")<br>    namespace             = optional(string, "cert-manager")<br>    namespace_labels      = optional(map(string), {})<br>    namespace_annotations = optional(map(string), {})<br>    create_namespace      = optional(bool, true)<br>    # Name of the ClusterIssuer to create.<br>    # Must match the cert-manager.io/cluster-issuer annotation used by other modules.<br>    cluster_issuer_name = optional(string, "selfsigned-cluster-issuer")<br><br>    # ClusterIssuer type and configuration.<br>    #   self_signed — issues a self-signed cert (default; good for internal/dev,<br>    #                 rejected by browsers for public ingress).<br>    #   acme        — ACME/Let's Encrypt with an HTTP-01 ingress solver. Requires<br>    #                 acme.email. Defaults to the Let's Encrypt production directory.<br>    #   ca          — signs off an existing CA keypair stored in ca.secret_name.<br>    issuer = optional(object({<br>      type = optional(string, "self_signed")<br>      acme = optional(object({<br>        server               = optional(string, "https://acme-v02.api.letsencrypt.org/directory")<br>        email                = optional(string, "")<br>        private_key_secret   = optional(string, "letsencrypt-account-key")<br>        solver_ingress_class = optional(string, "nginx")<br>      }), {})<br>      ca = optional(object({<br>        secret_name = optional(string, "")<br>      }), {})<br>    }), {})<br><br>    # Path to the kubeconfig file used by kubectl in local-exec provisioners.<br>    # When empty, kubectl uses its default resolution order (KUBECONFIG env var, then ~/.kube/config).<br>    kubeconfig_path = optional(string, "")<br><br>    # Helm release wait behaviour.<br>    wait          = optional(bool, true)<br>    wait_for_jobs = optional(bool, true)<br>    timeout       = optional(number, 300)<br><br>    # Pod scheduling, applied to all cert-manager components (controller,<br>    # webhook, cainjector, startupapicheck). tolerations let the pods schedule<br>    # onto tainted pools (e.g. GKE's kubernetes.io/arch=arm64:NoSchedule).<br>    node_selector = optional(map(string), {})<br>    tolerations = optional(list(object({<br>      key      = optional(string, "")<br>      operator = optional(string, "Equal")<br>      value    = optional(string, "")<br>      effect   = optional(string, "")<br>    })), [])<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_issuer_manifest"></a> [cluster\_issuer\_manifest](#output\_cluster\_issuer\_manifest) | Rendered ClusterIssuer manifest applied by the module (reflects issuer.type). |
| <a name="output_cluster_issuer_name"></a> [cluster\_issuer\_name](#output\_cluster\_issuer\_name) | Name of the ClusterIssuer created by the module. Use as the cert-manager.io/cluster-issuer annotation value. |
| <a name="output_helm_release_name"></a> [helm\_release\_name](#output\_helm\_release\_name) | Name of the Helm release. |
| <a name="output_helm_release_version"></a> [helm\_release\_version](#output\_helm\_release\_version) | Deployed chart version. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace where cert-manager is deployed. |

---

Maintained by [Digitalis.io](https://digitalis.io) — support at [digitalis.io/contact](https://digitalis.io/contact).
