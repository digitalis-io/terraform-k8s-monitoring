<div align="center">

<a href="https://digitalis.io/"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/DigitalisDigital_DigitalisFullLogoGradient+-+medium.png" alt="Digitalis.io" width="320"/></a>

# Grafana Alloy module

**Deploys the Grafana Alloy collector (daemonset / deployment / statefulset) with River/Alloy pipelines, sibling-module integration for Loki, Tempo, Mimir and Pyroscope, an optional Faro RUM receiver, and a sensitive-data (PII) redaction processor.**

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
| [helm_release.alloy](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.alloy](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alloy"></a> [alloy](#input\_alloy) | Grafana Alloy configuration. All fields are optional with safe defaults. | <pre>object({<br>    # Chart version from https://artifacthub.io/packages/helm/grafana/alloy<br>    chart_version         = optional(string, "0.12.5")<br>    namespace             = optional(string, "monitoring")<br>    namespace_labels      = optional(map(string), {})<br>    namespace_annotations = optional(map(string), {})<br>    create_namespace      = optional(bool, true)<br><br>    # Helm release wait behaviour.<br>    wait          = optional(bool, true)<br>    wait_for_jobs = optional(bool, true)<br>    timeout       = optional(number, 600)<br><br>    # Helm release name. Override when deploying more than one Alloy-based<br>    # release into the same namespace (e.g. a daemonset collector alongside a<br>    # deployment-mode gateway) so they don't collide.<br>    release_name = optional(string, "alloy")<br><br>    # Controller type determines the Kubernetes workload kind.<br>    # "daemonset"   — one pod per node; use for log/metric collection from every node<br>    # "deployment"  — fixed replica count; use for gateway/aggregation role<br>    # "statefulset" — stable pod identity; use when Alloy writes WAL to persistent storage<br>    controller_type = optional(string, "daemonset")<br><br>    # Number of replicas; ignored when controller_type = "daemonset"<br>    replicas = optional(number, 1)<br><br>    # Alloy pipeline configuration in River/Alloy syntax.<br>    # Written verbatim into the Helm chart's alloy.configMap.content value.<br>    # When empty, the module renders a built-in default config that wires non-empty<br>    # sibling endpoints automatically. Override with a full config string to take<br>    # complete control of all pipeline components.<br>    alloy_config = optional(string, "")<br><br>    # Opt-in Grafana Faro real-user-monitoring (RUM) receiver. When enabled and<br>    # alloy_config is empty, the built-in default config wires Alloy's<br>    # faro.receiver component (instead of the OTLP receiver) listening on<br>    # `port`, forwarding logs to loki_endpoint and traces to tempo_endpoint.<br>    # faro.receiver has no metrics output, so mimir_endpoint is not used here.<br>    # Deploy a second module "alloy" instance with a distinct release_name for<br>    # a Faro gateway alongside a separate OTLP daemonset collector.<br>    faro_receiver = optional(object({<br>      enabled = optional(bool, false)<br>      port    = optional(number, 12347) # 1-65535<br>    }), {})<br><br>    # Additional container ports exposed on the Alloy pod/Service, beyond the<br>    # default OTLP gRPC/HTTP ports. Use when alloy_config wires up a component<br>    # that listens on its own port (e.g. Alloy's faro.receiver).<br>    extra_ports = optional(list(object({<br>      name        = string<br>      port        = number<br>      target_port = number<br>      protocol    = optional(string, "TCP")<br>    })), [])<br><br>    # Persistence for WAL state — only meaningful when controller_type = "statefulset"<br>    persistence = optional(object({<br>      enabled       = optional(bool, false)<br>      storage_class = optional(string, "") # empty = cluster default<br>      size          = optional(string, "10Gi")<br>      access_mode   = optional(string, "ReadWriteOnce")<br>    }), {})<br><br>    resources = optional(object({<br>      requests_cpu    = optional(string, "100m")<br>      requests_memory = optional(string, "128Mi")<br>      limits_cpu      = optional(string, "500m")<br>      limits_memory   = optional(string, "512Mi")<br>    }), {})<br><br>    ingress = optional(object({<br>      enabled     = optional(bool, false)<br>      host        = optional(string, "")<br>      class_name  = optional(string, "nginx")<br>      tls_secret  = optional(string, "")<br>      annotations = optional(map(string), {})<br>    }), {})<br><br>    # Sibling-module integration — pass outputs from other modules directly.<br>    # Wired into the built-in default config when alloy_config = "".<br>    # When alloy_config is non-empty these are ignored; embed endpoints in your config string.<br>    loki_endpoint      = optional(string, "") # e.g. module.loki.datasource_url<br>    tempo_endpoint     = optional(string, "") # e.g. module.tempo.otlp_grpc_endpoint<br>    mimir_endpoint     = optional(string, "") # e.g. module.mimir.remote_write_endpoint<br>    mimir_tenant_id    = optional(string, "anonymous")<br>    pyroscope_endpoint = optional(string, "") # e.g. module.pyroscope.push_url<br>    otel_grpc_endpoint = optional(string, "") # e.g. module.otel.otlp_grpc_endpoint -- fans out alongside mimir/loki/tempo_endpoint (set any combination for direct-only, otel-only, or dual-write). Only honored by the OTLP-receiver config (faro_receiver.enabled = false); the Faro branch always sends logs/traces direct to loki/tempo_endpoint.<br><br>    # Continuous eBPF profiling: discovers pods annotated<br>    # `profiles.grafana.com/cpu.scrape: "true"` (standard Grafana/Pyroscope<br>    # convention) and profiles them via Alloy's pyroscope.ebpf component,<br>    # pushing to pyroscope_endpoint (must be set; a no-op otherwise). Requires<br>    # privileged + hostPID (eBPF needs kernel access and cross-container PID<br>    # visibility) -- only meaningful with controller_type = "daemonset" (one<br>    # profiler per node). Only wired into the built-in config (alloy_config<br>    # must be empty); a non-empty alloy_config takes full control.<br>    ebpf_profiling = optional(object({<br>      enabled          = optional(bool, false)<br>      collect_interval = optional(string, "15s")<br>      # none | simplified | templates | full -- C++/Rust symbol demangling detail.<br>      demangle = optional(string, "none")<br>    }), {})<br><br>    # Annotations added to the Alloy ServiceAccount.<br>    # Use for IRSA, GKE Workload Identity, or Azure Workload Identity.<br>    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.<br>    # Examples:<br>    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/alloy" }<br>    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "alloy@project.iam.gserviceaccount.com" }<br>    service_account_annotations = optional(map(string), {})<br><br>    # Pod scheduling. nodeSelector pins Alloy to matching nodes; tolerations<br>    # let it schedule onto tainted pools (e.g. an Arm64 node pool's<br>    # kubernetes.io/arch=arm64:NoSchedule taint).<br>    node_selector = optional(map(string), {})<br>    tolerations = optional(list(object({<br>      key      = optional(string, "")<br>      operator = optional(string, "Equal")<br>      value    = optional(string, "")<br>      effect   = optional(string, "")<br>    })), [])<br><br>    # Arbitrary extra Helm values merged last; highest precedence over the template.<br>    extra_values = optional(string, "")<br><br>    # Sensitive-data (PII) processor — hashes or deletes matched attributes on logs,<br>    # traces, and metrics before export. See https://opentelemetry.io/docs/security/handling-sensitive-data/<br>    # Enabled by default with a financial-institution-oriented ruleset (credit card<br>    # numbers, CVV, passwords/secrets/tokens, SSNs, IBANs/bank accounts, email<br>    # addresses). Only wired into the built-in config; a non-empty alloy_config<br>    # takes full control and must handle redaction itself.<br>    sensitive_data = optional(object({<br>      enabled               = optional(bool, true)<br>      action                = optional(string, "hash") # "hash" or "delete"<br>      default_rules_enabled = optional(bool, true)<br>      custom_rules          = optional(map(string), {}) # { "attribute.name" = "hash" | "delete" }<br>      salt                  = optional(string, "")      # mixed into the hash for deterministic, non-rainbow-table-able output<br>    }), {})<br>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_faro_receiver_http_endpoint"></a> [faro\_receiver\_http\_endpoint](#output\_faro\_receiver\_http\_endpoint) | In-cluster HTTP endpoint for the Faro receiver (only meaningful when faro\_receiver.enabled = true). Wire this into the Faro Web SDK baseUrl for applications running inside the cluster. |
| <a name="output_faro_receiver_public_url"></a> [faro\_receiver\_public\_url](#output\_faro\_receiver\_public\_url) | Public HTTP(S) URL for the Faro receiver — only set when faro\_receiver.enabled and ingress.enabled are both true. Use for browser-based applications running outside the cluster. |
| <a name="output_helm_release_id"></a> [helm\_release\_id](#output\_helm\_release\_id) | Helm release ID — used as a dependency anchor for other modules. |
| <a name="output_helm_release_name"></a> [helm\_release\_name](#output\_helm\_release\_name) | Name of the Helm release. |
| <a name="output_helm_release_version"></a> [helm\_release\_version](#output\_helm\_release\_version) | Deployed chart version. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace where Alloy is deployed. |
| <a name="output_otlp_grpc_endpoint"></a> [otlp\_grpc\_endpoint](#output\_otlp\_grpc\_endpoint) | OTLP gRPC endpoint exposed by Alloy (port 4317). Wire to instrumented applications. |
| <a name="output_otlp_http_endpoint"></a> [otlp\_http\_endpoint](#output\_otlp\_http\_endpoint) | OTLP HTTP endpoint exposed by Alloy (port 4318). Wire to instrumented applications. |

---

Maintained by [Digitalis.io](https://digitalis.io) — support at [digitalis.io/contact](https://digitalis.io/contact).
