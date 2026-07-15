locals {
  # Drop empty `value` so Exists-style tolerations render cleanly.
  cert_manager_tolerations = [
    for t in var.cert_manager.tolerations : merge(
      { key = t.key, operator = t.operator, effect = t.effect },
      t.value != "" ? { value = t.value } : {},
    )
  ]

  # Scheduling applied to every cert-manager component.
  cert_manager_scheduling = {
    nodeSelector = var.cert_manager.node_selector
    tolerations  = local.cert_manager_tolerations
  }

  # Common ClusterIssuer envelope; each issuer type merges its own spec on top.
  cert_manager_issuer_base = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.cert_manager.cluster_issuer_name
    }
  }

  # Full ClusterIssuer manifest, selected by issuer.type. Each branch yamlencodes
  # a complete manifest so the conditional yields a single type (string) — the
  # spec objects differ in shape and cannot be unified by a bare ternary.
  # yamlencode handles indentation and escaping, so there is no string
  # concatenation and no YAML/shell injection via the issuer name.
  cert_manager_cluster_issuer = (
    var.cert_manager.issuer.type == "acme" ? yamlencode(merge(local.cert_manager_issuer_base, {
      spec = {
        acme = {
          server              = var.cert_manager.issuer.acme.server
          email               = var.cert_manager.issuer.acme.email
          privateKeySecretRef = { name = var.cert_manager.issuer.acme.private_key_secret }
          solvers             = [{ http01 = { ingress = { class = var.cert_manager.issuer.acme.solver_ingress_class } } }]
        }
      }
      })) : var.cert_manager.issuer.type == "ca" ? yamlencode(merge(local.cert_manager_issuer_base, {
      spec = {
        ca = { secretName = var.cert_manager.issuer.ca.secret_name }
      }
    })) : yamlencode(merge(local.cert_manager_issuer_base, { spec = { selfSigned = {} } }))
  )

  cert_manager_kubectl = (
    var.cert_manager.kubeconfig_path != "" ?
    "kubectl --kubeconfig=${var.cert_manager.kubeconfig_path}" :
    "kubectl"
  )
}

resource "kubernetes_namespace" "cert_manager" {
  count = var.cert_manager.create_namespace ? 1 : 0

  metadata {
    name = var.cert_manager.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "cert-manager"
    }, var.cert_manager.namespace_labels)

    annotations = var.cert_manager.namespace_annotations
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

  values = [
    yamlencode(merge(
      {
        crds            = { enabled = true }
        nodeSelector    = local.cert_manager_scheduling.nodeSelector
        tolerations     = local.cert_manager_scheduling.tolerations
        webhook         = local.cert_manager_scheduling
        cainjector      = local.cert_manager_scheduling
        startupapicheck = local.cert_manager_scheduling
      },
    ))
  ]

  depends_on = [kubernetes_namespace.cert_manager]
}

# ClusterIssuer is applied via local-exec after cert-manager CRDs are installed.
# kubernetes_manifest validates against the live API at plan time, which fails
# when the CRD does not yet exist. terraform_data + local-exec defers the apply
# to after helm_release.cert_manager completes, avoiding that race condition.
#
# triggers_replace includes the rendered manifest, so any change to the issuer
# type/config or its name re-applies it (previously only a chart id change did).
resource "terraform_data" "cluster_issuer" {
  triggers_replace = [
    helm_release.cert_manager.id,
    local.cert_manager_cluster_issuer,
  ]

  provisioner "local-exec" {
    command = "${local.cert_manager_kubectl} apply -f - <<'YAML'\n${local.cert_manager_cluster_issuer}\nYAML"
  }

  depends_on = [helm_release.cert_manager]
}
