locals {
  _traces_list = compact([
    var.otel.tempo_endpoint != "" ? "otlp/tempo" : "",
    var.otel.otlphttp_traces_endpoint != "" ? "otlphttp/traces" : "",
    var.otel.clickhouse_endpoint != "" ? "clickhouse" : "",
  ])
  _logs_list = compact([
    var.otel.loki_endpoint != "" ? "otlphttp/loki" : "",
    var.otel.otlphttp_logs_endpoint != "" ? "otlphttp/logs" : "",
    var.otel.clickhouse_endpoint != "" ? "clickhouse" : "",
  ])
  _metrics_list = compact([
    var.otel.mimir_endpoint != "" ? "prometheusremotewrite" : "",
    var.otel.clickhouse_endpoint != "" ? "clickhouse" : "",
  ])

  traces_exporters  = length(local._traces_list) > 0 ? "[${join(", ", local._traces_list)}]" : "[debug]"
  metrics_exporters = length(local._metrics_list) > 0 ? "[${join(", ", local._metrics_list)}]" : "[debug]"
  logs_exporters    = length(local._logs_list) > 0 ? "[${join(", ", local._logs_list)}]" : "[debug]"
  logs_receivers    = var.otel.mode == "daemonset" ? "[otlp, filelog]" : "[otlp]"
  # daemonset: node OS metrics (hostmetrics) + per-node kubelet pod/container
  # metrics (kubeletstats). deployment: cluster-singleton object-state metrics
  # (k8s_cluster) — one watcher for the whole API, so it belongs on the single
  # deployment replica, never the per-node daemonset (would duplicate). The
  # `prometheus` receiver (scraping e.g. kube-state-metrics) is opt-in via
  # prometheus_scrape_targets, deployment mode only (a single scraper, like
  # k8s_cluster, not one per node).
  _metrics_receivers_deployment = concat(
    ["otlp", "k8s_cluster"],
    length(var.otel.prometheus_scrape_targets) > 0 ? ["prometheus"] : [],
  )
  metrics_receivers = var.otel.mode == "daemonset" ? "[otlp, hostmetrics, kubeletstats]" : "[${join(", ", local._metrics_receivers_deployment)}]"

  # Tolerations with empty `value` dropped (Exists-style entries), for the
  # operator Helm values (yamlencode).
  operator_tolerations = [
    for t in var.otel.tolerations : merge(
      { key = t.key, operator = t.operator, effect = t.effect },
      t.value != "" ? { value = t.value } : {},
    )
  ]
}

resource "kubernetes_namespace" "otel" {
  count = var.otel.create_namespace ? 1 : 0

  metadata {
    name = var.otel.namespace

    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }, var.otel.namespace_labels)

    annotations = merge({
    }, var.otel.namespace_annotations)
  }
}

resource "helm_release" "otel" {
  name       = var.otel.release_name
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.otel.chart_version
  namespace  = var.otel.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    sensitive(templatefile("${path.module}/helm-values/otel-collector.yaml.tftpl", {
      mode = var.otel.mode

      # Image
      image_repository  = var.otel.image.repository
      image_tag         = var.otel.image.tag
      image_pull_policy = var.otel.image.pull_policy

      # Exporter endpoints
      tempo_endpoint              = var.otel.tempo_endpoint
      mimir_endpoint              = var.otel.mimir_endpoint
      mimir_tenant_id             = var.otel.mimir_tenant_id
      loki_endpoint               = var.otel.loki_endpoint
      otlphttp_logs_endpoint      = var.otel.otlphttp_logs_endpoint
      otlphttp_traces_endpoint    = var.otel.otlphttp_traces_endpoint
      otlp_compression            = var.otel.otlp_compression
      service_namespace           = var.otel.service_namespace
      metrics_collection_interval = var.otel.metrics_collection_interval
      prometheus_scrape_targets   = var.otel.prometheus_scrape_targets
      clickhouse_username         = var.otel.clickhouse_username
      clickhouse_password         = var.otel.clickhouse_password
      clickhouse_database         = var.otel.clickhouse_database
      clickhouse_create_schema    = var.otel.clickhouse_create_schema
      clickhouse_cluster          = var.otel.clickhouse_cluster
      clickhouse_table_engine     = var.otel.clickhouse_table_engine

      # Structured-log (filelog) parsing knobs
      log_json_enabled    = var.otel.log_parsing.json_enabled
      log_json_match_expr = var.otel.log_parsing.json_match_expr
      log_severity_field  = var.otel.log_parsing.severity_field
      log_trace_enabled   = var.otel.log_parsing.trace_enabled
      log_trace_id_field  = var.otel.log_parsing.trace_id_field
      log_span_id_field   = var.otel.log_parsing.span_id_field

      # Pre-computed pipeline lists
      traces_exporters    = local.traces_exporters
      metrics_exporters   = local.metrics_exporters
      logs_exporters      = local.logs_exporters
      logs_receivers      = local.logs_receivers
      metrics_receivers   = local.metrics_receivers
      clickhouse_endpoint = var.otel.clickhouse_endpoint

      # Resource requests/limits
      requests_cpu    = var.otel.resources.requests_cpu
      requests_memory = var.otel.resources.requests_memory
      limits_cpu      = var.otel.resources.limits_cpu
      limits_memory   = var.otel.resources.limits_memory

      service_account_annotations = var.otel.service_account_annotations

      # Scheduling
      node_selector = var.otel.node_selector
      tolerations   = var.otel.tolerations
    }))
  ]

  depends_on = [kubernetes_namespace.otel]
}

resource "helm_release" "otel_operator" {
  count = try(var.otel.operator.enabled, false) ? 1 : 0

  name       = "otel-operator"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-operator"
  version    = try(var.otel.operator.chart_version, "0.116.0")
  namespace  = var.otel.namespace

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 300

  values = [
    yamlencode({
      # Schedule the operator manager onto tainted pools (e.g. arm64).
      nodeSelector = var.otel.node_selector
      tolerations  = local.operator_tolerations
      manager = {
        collectorImage = {
          repository = try(var.otel.operator.collector_image_repository, "otel/opentelemetry-collector-k8s")
        }
        extraArgs = try(var.otel.operator.extra_args, [])
        autoInstrumentation = {
          go = {
            enabled = try(var.otel.operator.go_instrumentation_enabled, false)
          }
        }
        autoInstrumentationImage = {
          java        = { repository = "", tag = "" }
          nodejs      = { repository = "", tag = "" }
          python      = { repository = "", tag = "" }
          dotnet      = { repository = "", tag = "" }
          apacheHttpd = { repository = "", tag = "" }
          nginx       = { repository = "", tag = "" }
          go = {
            repository = try(var.otel.operator.go_instrumentation_image, "")
            tag        = ""
          }
        }
      }
      admissionWebhooks = {
        certManager      = { enabled = try(var.otel.operator.cert_manager_enabled, false) }
        autoGenerateCert = { enabled = try(var.otel.operator.auto_generate_cert_enabled, true) }
      }
    })
  ]

  depends_on = [kubernetes_namespace.otel]
}
