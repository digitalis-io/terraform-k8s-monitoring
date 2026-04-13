variable "cert_manager" {
  description = "cert-manager configuration."
  type = object({
    chart_version        = optional(string, "v1.19.1")
    namespace            = optional(string, "cert-manager")
    create_namespace     = optional(bool, true)
    # Name of the self-signed ClusterIssuer to create.
    # Must match the cert-manager.io/cluster-issuer annotation used by other modules.
    cluster_issuer_name  = optional(string, "selfsigned-cluster-issuer")
  })
  default = {}
}
