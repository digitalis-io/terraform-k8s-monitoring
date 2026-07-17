locals {
  _traces_list = compact([
    var.otel.tempo_endpoint != "" ? "otlp/tempo" : "",
    var.otel.otlphttp_traces_endpoint != "" ? "otlphttp/traces" : "",
    var.otel.clickhouse_endpoint != "" ? "clickhouse" : "",
  ])
  # When a gigapipe label allowlist is set, the otlphttp/logs (gigapipe) exporter
  # moves to its own logs/gigapipe pipeline (with the keep_keys trim), so it is
  # dropped from the main logs pipeline here to avoid a double-write.
  _logs_split_gigapipe = var.otel.otlphttp_logs_endpoint != "" && length(var.otel.logs_gigapipe_label_allowlist) > 0
  _logs_list = compact([
    var.otel.loki_endpoint != "" ? "otlphttp/loki" : "",
    (var.otel.otlphttp_logs_endpoint != "" && !local._logs_split_gigapipe) ? "otlphttp/logs" : "",
    var.otel.clickhouse_endpoint != "" ? "clickhouse" : "",
  ])
  # OTTL string-list literal for keep_keys, e.g. `"service.name", "k8s.namespace.name"`.
  # Empty string => feature off (no split pipeline, no processor).
  gigapipe_label_keep = local._logs_split_gigapipe ? join(", ", [
    for k in var.otel.logs_gigapipe_label_allowlist : "\"${k}\""
  ]) : ""
  _metrics_list = compact([
    var.otel.mimir_endpoint != "" ? "prometheusremotewrite" : "",
    var.otel.mimir2_endpoint != "" ? "prometheusremotewrite/mimir2" : "",
    var.otel.clickhouse_endpoint != "" ? "clickhouse" : "",
  ])

  # Kafka buffering role. Only active when brokers is set. producer -> the signal
  # pipeline exporters become the kafka exporters (defined in the template);
  # consumer -> template swaps the pipeline receivers to kafka and keeps the
  # backend exporters computed below.
  kafka_role      = var.otel.kafka.brokers != "" ? var.otel.kafka.role : ""
  _kafka_producer = local.kafka_role == "producer"
  # YAML list body for `brokers: [${kafka_brokers}]`, one quoted host:port each.
  kafka_brokers_yaml = join(", ", [for b in split(",", var.otel.kafka.brokers) : "\"${trimspace(b)}\""])

  traces_exporters  = local._kafka_producer ? "[kafka/traces]" : (length(local._traces_list) > 0 ? "[${join(", ", local._traces_list)}]" : "[debug]")
  metrics_exporters = local._kafka_producer ? "[kafka/metrics]" : (length(local._metrics_list) > 0 ? "[${join(", ", local._metrics_list)}]" : "[debug]")
  logs_exporters    = local._kafka_producer ? "[kafka/logs]" : (length(local._logs_list) > 0 ? "[${join(", ", local._logs_list)}]" : "[debug]")
  logs_receivers    = var.otel.mode == "daemonset" ? "[otlp, filelog]" : "[otlp]"
  # daemonset: node OS metrics (hostmetrics) + per-node kubelet pod/container
  # metrics (kubeletstats). deployment: cluster-singleton object-state metrics
  # (k8s_cluster) — one watcher for the whole API, so it belongs on the single
  # deployment replica, never the per-node daemonset (would duplicate). The
  # `prometheus` receiver (scraping e.g. kube-state-metrics) is opt-in via
  # prometheus_scrape_targets, deployment mode only (a single scraper, like
  # k8s_cluster, not one per node).
  # Strimzi/Kafka scrape receiver (prometheus/strimzi). Deployment mode only.
  # Added to the metrics pipeline receivers for BOTH the direct/producer gateway
  # and the consumer (the consumer branch wires it via consumer_metrics_receivers
  # below), so a Kafka-buffered topology can scrape Kafka on whichever collector
  # writes the store directly.
  kafka_scrape_enabled = var.otel.mode == "deployment" && var.otel.kafka_metrics_scrape.enabled
  # Cluster-wide annotation-based pod scrape (prometheus/pods). Deployment only.
  pod_scrape_enabled = var.otel.mode == "deployment" && var.otel.prometheus_pod_scrape.enabled
  # Opt-in scrape receivers shared by the direct/producer gateway (metrics_receivers)
  # and the consumer (consumer_metrics_receivers) so a Kafka-buffered topology
  # scrapes on whichever collector writes the store directly (bypassing the buffer).
  _extra_scrape_receivers = concat(
    local.kafka_scrape_enabled ? ["prometheus/strimzi"] : [],
    local.pod_scrape_enabled ? ["prometheus/pods"] : [],
  )
  _metrics_receivers_deployment = concat(
    ["otlp", "k8s_cluster"],
    length(var.otel.prometheus_scrape_targets) > 0 ? ["prometheus"] : [],
    local._extra_scrape_receivers,
  )
  metrics_receivers          = var.otel.mode == "daemonset" ? "[otlp, hostmetrics, kubeletstats]" : "[${join(", ", local._metrics_receivers_deployment)}]"
  consumer_metrics_receivers = "[${join(", ", concat(["kafka/metrics"], local._extra_scrape_receivers))}]"

  # Tolerations with empty `value` dropped (Exists-style entries), for the
  # operator Helm values (yamlencode).
  operator_tolerations = [
    for t in var.otel.tolerations : merge(
      { key = t.key, operator = t.operator, effect = t.effect },
      t.value != "" ? { value = t.value } : {},
    )
  ]

  # ClickHouse credentials: prefer a caller-supplied Secret; otherwise, when a
  # plaintext password is given, auto-create a Secret so the credential is
  # injected via secretKeyRef + $${env:...} expansion rather than rendered into
  # the Helm values / Terraform state.
  otel_create_clickhouse_secret = (
    var.otel.clickhouse_endpoint != "" &&
    var.otel.clickhouse_credentials_secret == null &&
    var.otel.clickhouse_password != ""
  )
  otel_clickhouse_secret = (
    var.otel.clickhouse_credentials_secret != null ? var.otel.clickhouse_credentials_secret :
    local.otel_create_clickhouse_secret ? {
      name         = "${var.otel.release_name}-clickhouse-credentials"
      username_key = "username"
      password_key = "password"
    } : null
  )
}

resource "kubernetes_secret" "otel_clickhouse_credentials" {
  count = local.otel_create_clickhouse_secret ? 1 : 0

  metadata {
    name      = "${var.otel.release_name}-clickhouse-credentials"
    namespace = var.otel.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    username = var.otel.clickhouse_username
    password = var.otel.clickhouse_password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.otel]
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
  wait             = var.otel.wait
  wait_for_jobs    = var.otel.wait_for_jobs
  timeout          = var.otel.timeout

  values = [
    sensitive(templatefile("${path.module}/helm-values/otel-collector.yaml.tftpl", {
      mode     = var.otel.mode
      replicas = var.otel.replicas

      # Image
      image_repository  = var.otel.image.repository
      image_tag         = var.otel.image.tag
      image_pull_policy = var.otel.image.pull_policy

      # Exporter endpoints
      tempo_endpoint           = var.otel.tempo_endpoint
      mimir_endpoint           = var.otel.mimir_endpoint
      mimir_tenant_id          = var.otel.mimir_tenant_id
      mimir2_endpoint          = var.otel.mimir2_endpoint
      mimir2_tenant_id         = var.otel.mimir2_tenant_id
      loki_endpoint            = var.otel.loki_endpoint
      otlphttp_logs_endpoint   = var.otel.otlphttp_logs_endpoint
      otlphttp_traces_endpoint = var.otel.otlphttp_traces_endpoint
      otlp_compression         = var.otel.otlp_compression

      otlp_grpc_max_recv_msg_size_mib = var.otel.otlp_grpc_max_recv_msg_size_mib
      service_namespace               = var.otel.service_namespace
      metrics_collection_interval     = var.otel.metrics_collection_interval
      hostmetrics_process_enabled     = var.otel.hostmetrics_process_enabled
      prometheus_scrape_targets       = var.otel.prometheus_scrape_targets

      # Strimzi/Kafka scrape receiver (prometheus/strimzi)
      kafka_metrics_scrape_enabled   = local.kafka_scrape_enabled
      kafka_metrics_scrape_namespace = var.otel.kafka_metrics_scrape.namespace
      kafka_metrics_scrape_interval  = var.otel.kafka_metrics_scrape.interval
      consumer_metrics_receivers     = local.consumer_metrics_receivers

      # Annotation-based pod scrape receiver (prometheus/pods)
      pod_scrape_enabled             = local.pod_scrape_enabled
      pod_scrape_namespaces          = var.otel.prometheus_pod_scrape.namespaces
      pod_scrape_interval            = var.otel.prometheus_pod_scrape.interval
      clickhouse_username            = var.otel.clickhouse_username
      clickhouse_password            = var.otel.clickhouse_password
      clickhouse_database            = var.otel.clickhouse_database
      clickhouse_create_schema       = var.otel.clickhouse_create_schema
      clickhouse_cluster             = var.otel.clickhouse_cluster
      clickhouse_table_engine        = var.otel.clickhouse_table_engine
      use_clickhouse_secret          = local.otel_clickhouse_secret != null
      clickhouse_secret_name         = local.otel_clickhouse_secret != null ? local.otel_clickhouse_secret.name : ""
      clickhouse_secret_username_key = local.otel_clickhouse_secret != null ? local.otel_clickhouse_secret.username_key : ""
      clickhouse_secret_password_key = local.otel_clickhouse_secret != null ? local.otel_clickhouse_secret.password_key : ""

      # Structured-log (filelog) parsing knobs
      log_json_enabled    = var.otel.log_parsing.json_enabled
      log_json_match_expr = var.otel.log_parsing.json_match_expr
      log_severity_field  = var.otel.log_parsing.severity_field
      log_trace_enabled   = var.otel.log_parsing.trace_enabled
      log_trace_id_field  = var.otel.log_parsing.trace_id_field
      log_span_id_field   = var.otel.log_parsing.span_id_field
      log_service_field   = var.otel.log_parsing.service_field

      # Pre-computed pipeline lists
      traces_exporters    = local.traces_exporters
      metrics_exporters   = local.metrics_exporters
      logs_exporters      = local.logs_exporters
      logs_receivers      = local.logs_receivers
      gigapipe_label_keep = local.gigapipe_label_keep
      metrics_receivers   = local.metrics_receivers
      clickhouse_endpoint = var.otel.clickhouse_endpoint

      # Kafka buffering
      kafka_role              = local.kafka_role
      kafka_brokers           = local.kafka_brokers_yaml
      kafka_metrics_topic     = var.otel.kafka.metrics_topic
      kafka_logs_topic        = var.otel.kafka.logs_topic
      kafka_traces_topic      = var.otel.kafka.traces_topic
      kafka_encoding          = var.otel.kafka.encoding
      kafka_consumer_group    = var.otel.kafka.consumer_group
      kafka_max_message_bytes = var.otel.kafka.max_message_bytes

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

  depends_on = [kubernetes_namespace.otel, kubernetes_secret.otel_clickhouse_credentials]
}

resource "helm_release" "otel_operator" {
  count = try(var.otel.operator.enabled, false) ? 1 : 0

  name       = "otel-operator"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-operator"
  version    = try(var.otel.operator.chart_version, "0.120.0")
  namespace  = var.otel.namespace

  create_namespace = false
  wait             = var.otel.wait
  wait_for_jobs    = var.otel.wait_for_jobs
  timeout          = var.otel.timeout

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
