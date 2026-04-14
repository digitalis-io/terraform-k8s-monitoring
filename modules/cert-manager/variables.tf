variable "cert_manager" {
  description = "cert-manager configuration."
  type = object({
    chart_version         = optional(string, "v1.19.1")
    namespace             = optional(string, "cert-manager")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    # Name of the self-signed ClusterIssuer to create.
    # Must match the cert-manager.io/cluster-issuer annotation used by other modules.
    cluster_issuer_name = optional(string, "selfsigned-cluster-issuer")
    # Path to the kubeconfig file used by kubectl in local-exec provisioners.
    # Defaults to ~/.kube/config. Set explicitly to avoid KUBECONFIG env var interference.
    kubeconfig_path = optional(string, "")
  })
  default = {}
}
