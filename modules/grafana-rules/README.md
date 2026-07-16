<div align="center">

<a href="https://digitalis.io/"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="320"/></a>

# Grafana Alert Rules module

**Provisions Grafana-managed alert rules and per-channel notification contact points (Slack, PagerDuty, webhook, email) with per-channel minimum-severity routing.**

</div>

Part of [terraform-k8s-monitoring](../../README.md). See the root README for full usage, examples and storage configuration guidance.

## Reference

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.36 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_config_map.grafana_rule](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_secret.grafana_contact_points](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_grafana_rules"></a> [grafana\_rules](#input\_grafana\_rules) | Grafana-managed alert rules and notification contact points. | <pre>object({<br>    # Namespace must match where kube-prometheus-stack (Grafana) is deployed.<br>    namespace = optional(string, "monitoring")<br><br>    # Additional alert rule YAML files supplied by the caller.<br>    # key = filename (e.g. "my-app.yaml"), value = YAML content via file().<br>    # Merged with the bundled rules in modules/grafana-rules/rules/.<br>    extra_rules = optional(map(string), {})<br><br>    # Slack contact point.<br>    slack = optional(object({<br>      enabled     = optional(bool, false)<br>      webhook_url = optional(string, "")<br>      channel     = optional(string, "#alerts")<br>      # Minimum severity label value to match. Values: "critical" | "warning" | "info"<br>      min_severity = optional(string, "warning")<br>    }), {})<br><br>    # PagerDuty contact point.<br>    pagerduty = optional(object({<br>      enabled         = optional(bool, false)<br>      integration_key = optional(string, "")<br>      min_severity    = optional(string, "critical")<br>    }), {})<br><br>    # Generic webhook contact point (e.g. for OpsGenie, VictorOps, custom receivers).<br>    webhook = optional(object({<br>      enabled      = optional(bool, false)<br>      url          = optional(string, "")<br>      http_method  = optional(string, "POST")<br>      min_severity = optional(string, "warning")<br>    }), {})<br><br>    # Email contact point.<br>    email = optional(object({<br>      enabled      = optional(bool, false)<br>      addresses    = optional(list(string), [])<br>      min_severity = optional(string, "critical")<br>    }), {})<br>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_contact_points_secret_name"></a> [contact\_points\_secret\_name](#output\_contact\_points\_secret\_name) | Name of the Secret holding the contact points and notification policy, or null when no channel is enabled. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace where the alert rules and contact points are provisioned. |
| <a name="output_rule_configmap_names"></a> [rule\_configmap\_names](#output\_rule\_configmap\_names) | Names of the ConfigMaps holding the provisioned Grafana alert rules (one per rule YAML). |

---

Maintained by [Digitalis.io](https://digitalis.io) — support at [digitalis.io/contact](https://digitalis.io/contact).
