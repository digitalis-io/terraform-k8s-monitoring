variable "cert_manager" {
  description = "cert-manager configuration."
  type = object({
    chart_version         = optional(string, "v1.19.1")
    namespace             = optional(string, "cert-manager")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    # Name of the ClusterIssuer to create.
    # Must match the cert-manager.io/cluster-issuer annotation used by other modules.
    cluster_issuer_name = optional(string, "selfsigned-cluster-issuer")

    # ClusterIssuer type and configuration.
    #   self_signed — issues a self-signed cert (default; good for internal/dev,
    #                 rejected by browsers for public ingress).
    #   acme        — ACME/Let's Encrypt with an HTTP-01 ingress solver. Requires
    #                 acme.email. Defaults to the Let's Encrypt production directory.
    #   ca          — signs off an existing CA keypair stored in ca.secret_name.
    issuer = optional(object({
      type = optional(string, "self_signed")
      acme = optional(object({
        server               = optional(string, "https://acme-v02.api.letsencrypt.org/directory")
        email                = optional(string, "")
        private_key_secret   = optional(string, "letsencrypt-account-key")
        solver_ingress_class = optional(string, "nginx")
      }), {})
      ca = optional(object({
        secret_name = optional(string, "")
      }), {})
    }), {})

    # Path to the kubeconfig file used by kubectl in local-exec provisioners.
    # When empty, kubectl uses its default resolution order (KUBECONFIG env var, then ~/.kube/config).
    kubeconfig_path = optional(string, "")

    # Helm release wait behaviour.
    wait          = optional(bool, true)
    wait_for_jobs = optional(bool, true)
    timeout       = optional(number, 300)

    # Pod scheduling, applied to all cert-manager components (controller,
    # webhook, cainjector, startupapicheck). tolerations let the pods schedule
    # onto tainted pools (e.g. GKE's kubernetes.io/arch=arm64:NoSchedule).
    node_selector = optional(map(string), {})
    tolerations = optional(list(object({
      key      = optional(string, "")
      operator = optional(string, "Equal")
      value    = optional(string, "")
      effect   = optional(string, "")
    })), [])
  })
  default = {}

  validation {
    condition     = var.cert_manager.cluster_issuer_name != ""
    error_message = "cert_manager.cluster_issuer_name must not be empty."
  }

  validation {
    # ClusterIssuer names must be RFC 1123 DNS subdomains. Enforcing this also
    # prevents newline/metacharacter injection into the rendered manifest.
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$", var.cert_manager.cluster_issuer_name)) && length(var.cert_manager.cluster_issuer_name) <= 253
    error_message = "cert_manager.cluster_issuer_name must be a valid RFC 1123 DNS subdomain (lowercase alphanumerics, '-' and '.', max 253 chars)."
  }

  validation {
    condition     = contains(["self_signed", "acme", "ca"], var.cert_manager.issuer.type)
    error_message = "cert_manager.issuer.type must be one of: self_signed, acme, ca."
  }

  validation {
    condition     = var.cert_manager.issuer.type != "acme" || var.cert_manager.issuer.acme.email != ""
    error_message = "cert_manager.issuer.acme.email is required when issuer.type = \"acme\" (ACME registration needs a contact email)."
  }

  validation {
    condition     = var.cert_manager.issuer.type != "ca" || var.cert_manager.issuer.ca.secret_name != ""
    error_message = "cert_manager.issuer.ca.secret_name is required when issuer.type = \"ca\"."
  }
}
