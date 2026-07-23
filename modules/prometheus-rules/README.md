<div align="center">

<a href="https://digitalis.io/"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="320"/></a>

# Prometheus Alert Rules module

**Applies PrometheusRule alert definitions and an AlertmanagerConfig routing alerts to Slack and/or PagerDuty by minimum severity.**

</div>

Part of [terraform-k8s-monitoring](../../README.md). See the root README for full usage, examples and storage configuration guidance.

## Reference

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.36 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_secret.pagerduty](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.slack](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [terraform_data.alertmanager_config](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.prometheus_rule](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_prometheus_rules"></a> [prometheus\_rules](#input\_prometheus\_rules) | Prometheus alert rules and Alertmanager receiver configuration. | <pre>object({<br>    # Namespace must match where kube-prometheus-stack is deployed.<br>    namespace = optional(string, "monitoring")<br><br>    # Path to the kubeconfig file used by kubectl in local-exec provisioners.<br>    # When empty, kubectl uses its default resolution order (KUBECONFIG env var, then ~/.kube/config).<br>    kubeconfig_path = optional(string, "")<br><br>    # Output from module.prometheus.helm_release_id — enforces apply order so<br>    # PrometheusRule and AlertmanagerConfig CRDs exist before kubectl apply runs.<br>    prometheus_release_id = string<br><br>    # Additional alert rule YAML files supplied by the caller.<br>    # key = filename (e.g. "my-app.yaml"), value = YAML content via file().<br>    # Merged with the bundled rules in modules/prometheus-rules/rules/.<br>    # Example: { "my-app.yaml" = file("${path.module}/rules/my-app.yaml") }<br>    extra_rules = optional(map(string), {})<br><br>    # Slack receiver — leave enabled=false (default) to skip.<br>    slack = optional(object({<br>      enabled     = optional(bool, false)<br>      webhook_url = optional(string, "")<br>      channel     = optional(string, "#alerts")<br>      # Minimum severity to route to Slack. Alerts below this are suppressed.<br>      # Values: "critical" | "warning" | "info"<br>      min_severity = optional(string, "warning")<br>    }), {})<br><br>    # PagerDuty receiver — leave enabled=false (default) to skip.<br>    pagerduty = optional(object({<br>      enabled     = optional(bool, false)<br>      routing_key = optional(string, "")<br>      # Only critical alerts go to PagerDuty by default.<br>      min_severity = optional(string, "critical")<br>    }), {})<br>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alertmanager_config_applied"></a> [alertmanager\_config\_applied](#output\_alertmanager\_config\_applied) | Whether an AlertmanagerConfig was applied (true when at least one receiver is enabled). |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace where the PrometheusRules and AlertmanagerConfig are applied. |
| <a name="output_rule_names"></a> [rule\_names](#output\_rule\_names) | Filenames (keys) of the PrometheusRule manifests applied by the module. |

---

Maintained by [Digitalis.io](https://digitalis.io) — support at [digitalis.io/contact](https://digitalis.io/contact).
