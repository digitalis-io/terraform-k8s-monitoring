resource "kubernetes_namespace" "cert_manager" {
  count = var.cert_manager.create_namespace ? 1 : 0

  metadata {
    name = var.cert_manager.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "cert-manager"
    }
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts"
  chart            = "cert-manager"
  version          = var.cert_manager.chart_version
  namespace        = var.cert_manager.namespace
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 300

  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

# ClusterIssuer is applied via local-exec after cert-manager CRDs are installed.
# kubernetes_manifest validates against the live API at plan time, which fails
# when the CRD does not yet exist. terraform_data + local-exec defers the apply
# to after helm_release.cert_manager completes, avoiding that race condition.
resource "terraform_data" "cluster_issuer" {
  triggers_replace = [helm_release.cert_manager.id]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'YAML'
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: ${var.cert_manager.cluster_issuer_name}
      spec:
        selfSigned: {}
      YAML
    EOT
  }

  depends_on = [helm_release.cert_manager]
}
