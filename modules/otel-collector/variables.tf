variable "otel" {
  description = "OpenTelemetry Collector configuration. All fields are optional with safe defaults."
  type = object({
    chart_version         = optional(string, "0.165.0")
    namespace             = optional(string, "monitoring")
    namespace_labels      = optional(map(string), {})
    namespace_annotations = optional(map(string), {})
    create_namespace      = optional(bool, true)
    # Helm release readiness. wait/wait_for_jobs block apply until resources are
    # ready; set wait = false for async/GitOps rollouts. Applies to both the
    # collector and (when enabled) the operator release.
    wait          = optional(bool, true)
    wait_for_jobs = optional(bool, true)
    timeout       = optional(number, 600)
    mode          = optional(string, "daemonset") # daemonset | deployment
    # Deployment/StatefulSet replica count. Ignored in daemonset mode (one pod
    # per node). Raise for a deployment gateway that must absorb a high OTLP
    # ingest rate -- a single replica is a throughput bottleneck.
    replicas = optional(number, 1)
    # Helm release name. Override when running two collectors in one namespace
    # (e.g. a "deployment" gateway plus a "daemonset" log/host agent).
    release_name = optional(string, "otel")

    # Wire from sibling module outputs
    tempo_endpoint  = optional(string, "")          # OTLP gRPC :4317 -- use module.tempo.otlp_grpc_endpoint
    mimir_endpoint  = optional(string, "")          # remote_write URL -- use module.mimir.remote_write_endpoint
    mimir_tenant_id = optional(string, "anonymous") # X-Scope-OrgID header -- wire from module.mimir.tenant_id
    # Second, independent Prometheus remote_write target. Lets metrics dual-write
    # to two backends at once (e.g. an eval candidate on mimir_endpoint plus a
    # real Mimir instance here) without one exporter replacing the other.
    mimir2_endpoint  = optional(string, "")
    mimir2_tenant_id = optional(string, "anonymous")
    loki_endpoint    = optional(string, "") # Loki push :3100 -- use module.loki.datasource_url
    # Static scrape targets for an additional `prometheus` receiver
    # (mode = "deployment" only) -- e.g. a kube-state-metrics Service
    # ("kube-state-metrics.monitoring.svc:8080"). Empty list omits the
    # receiver entirely.
    prometheus_scrape_targets = optional(list(string), [])
    # Generic OTLP/HTTP exporters for backends that speak plain OTLP/HTTP but
    # don't match the Loki (`<endpoint>/otlp`) or Tempo (gRPC :4317) conventions
    # above -- e.g. gigapipe's native /v1/logs and /v1/traces routes. Each is a
    # base URL; the otlphttp exporter appends /v1/logs or /v1/traces itself.
    otlphttp_logs_endpoint   = optional(string, "")
    otlphttp_traces_endpoint = optional(string, "")
    # Resource-attribute allowlist for the gigapipe (otlphttp/logs) path. gigapipe
    # indexes every resource attr as a label (no metadata tier), so a raw
    # dual-write indexes far more labels than Loki's index_label_attributes
    # allowlist. When set (and otlphttp_logs_endpoint != ""), logs to gigapipe run
    # a separate pipeline that keep_keys()-trims resource attrs to this list, so
    # gigapipe and Loki index the same labels. [] => off (gigapipe indexes all).
    # Set this to the SAME list as the Loki module's index_label_attributes.
    logs_gigapipe_label_allowlist = optional(list(string), [])
    # Wire-compression for the OTLP exporters (otlp/tempo, otlphttp/loki,
    # otlphttp/logs, otlphttp/traces). OTLP defaults to no compression, so on a
    # zone-spread cluster every export leg pays inter-zone egress on raw bytes;
    # gzip/zstd typically shrink telemetry ~5-10x. "none" disables it.
    # prometheusremotewrite is always snappy-compressed (spec) and unaffected.
    otlp_compression = optional(string, "gzip")
    # Max gRPC receive message size (MiB) for the OTLP gRPC receiver. gRPC's
    # default is 4 MiB; raise it when producers send batches that exceed 4 MiB
    # after decompression (the receiver otherwise rejects them with
    # ResourceExhausted). Only affects the gRPC receiver (:4317).
    otlp_grpc_max_recv_msg_size_mib = optional(number, 4)
    # Stamp service.namespace on telemetry that lacks it (host/node metrics from
    # the hostmetrics/kubeletstats receivers) via a resource processor with
    # action=insert, so OTel dashboards that filter on service.namespace (e.g.
    # Grafana 20376) resolve. Empty disables the processor.
    service_namespace = optional(string, "")
    # Uniform collection_interval override for the metrics receivers below
    # (hostmetrics, kubeletstats, k8s_cluster) -- each otherwise defaults to a
    # different interval (10s/20s/30s). Empty keeps those per-receiver defaults.
    metrics_collection_interval = optional(string, "")
    # Per-PID process metrics on the daemonset hostmetrics receiver. Off by
    # default: a series per PID (very high cardinality) and it carries
    # process.command_line, which a remote-write backend promotes to an oversized
    # label (node command lines exceed Mimir's 2048-char label limit -> the series
    # is rejected with err-mimir-label-value-too-long). Enable only when you need
    # per-process series; the unbounded attributes are dropped even then.
    hostmetrics_process_enabled = optional(bool, false)
    clickhouse_endpoint         = optional(string, "")     # ClickHouse HTTP :8123 -- use module.clickhouse.http_endpoint
    clickhouse_username         = optional(string, "")     # ClickHouse username for OTLP/ClickHouse exporter
    clickhouse_password         = optional(string, "")     # ClickHouse password for OTLP/ClickHouse exporter
    clickhouse_database         = optional(string, "otel") # ClickHouse database for OTLP/ClickHouse exporter
    clickhouse_create_schema    = optional(bool, true)     # auto-create DB/tables on startup
    clickhouse_cluster          = optional(string, "")     # cluster name -> ON CLUSTER DDL (creates tables on all nodes)
    clickhouse_table_engine     = optional(string, "")     # e.g. ReplicatedMergeTree (pair with clickhouse_cluster for replication)
    # Reference a pre-existing Secret holding the ClickHouse username/password.
    # When set, credentials are injected via secretKeyRef + ${env:...} expansion
    # rather than rendered plaintext into the Helm values / Terraform state.
    # Mutually exclusive with clickhouse_username/clickhouse_password. When null
    # and clickhouse_password is set, the module auto-creates a Secret instead.
    clickhouse_credentials_secret = optional(object({
      name         = string
      username_key = optional(string, "username")
      password_key = optional(string, "password")
    }), null)

    # Structured-log parsing for the daemonset `filelog` receiver.
    # Promotes trace context and severity from JSON pod logs into native OTel
    # fields (fills ClickHouse otel_logs.TraceId/SpanId/SeverityText and enables
    # log<->trace correlation). Only applies in mode = "daemonset".
    log_parsing = optional(object({
      # Master switch for the json_parser operator. When false, the filelog
      # receiver uses only the `container` operator (bodies stay opaque).
      json_enabled = optional(bool, true)

      # Raw OTel filelog `if` expression that guards JSON parsing, so plain-text
      # logs pass through untouched. Default matches lines whose (leading-space-
      # trimmed) body starts with '{'. Advanced: this is an expr-lang expression
      # rendered inside a single-quoted YAML scalar -- mind expr/YAML escaping if
      # you override it (e.g. use hasPrefix(body, "{") to avoid regex backslashes).
      json_match_expr = optional(string, "body matches \"^\\\\s*[{]\"")

      # JSON field mapped to SeverityText/SeverityNumber. Empty ("") disables
      # severity mapping.
      severity_field = optional(string, "level")

      # Promote trace_id/span_id JSON fields into the log record's trace context.
      # Requires json_enabled = true.
      trace_enabled  = optional(bool, true)
      trace_id_field = optional(string, "trace_id")
      span_id_field  = optional(string, "span_id")

      # JSON body field promoted to the OTel resource `service.name` (so stdout
      # logs carrying their own service field aren't bucketed as
      # `unknown_service`). Requires json_enabled = true. "" disables the promotion.
      service_field = optional(string, "service")
    }), {})

    image = optional(object({
      # contrib includes prometheusremotewrite and loki exporters required for Mimir/Loki forwarding
      repository  = optional(string, "otel/opentelemetry-collector-contrib")
      tag         = optional(string, "") # empty = chart appVersion
      pull_policy = optional(string, "IfNotPresent")
    }), {})

    resources = optional(object({
      requests_cpu    = optional(string, "300m")
      requests_memory = optional(string, "256Mi")
      limits_cpu      = optional(string, "500m")
      limits_memory   = optional(string, "512Mi")
    }), {})

    # Annotations to add to the OpenTelemetry Collector ServiceAccount.
    # Use this for IRSA, GKE Workload Identity, or Azure Workload Identity.
    # No IAM resources are created by this module; pre-create the role/SA and supply the annotation here.
    # Examples:
    #   IRSA:              { "eks.amazonaws.com/role-arn" = "arn:aws:iam::123456789012:role/otel" }
    #   Workload Identity: { "iam.gke.io/gcp-service-account" = "otel@project.iam.gserviceaccount.com" }
    service_account_annotations = optional(map(string), {})

    # Pod scheduling. nodeSelector pins the collector to matching nodes;
    # tolerations let it schedule onto tainted pools (e.g. GKE's automatic
    # kubernetes.io/arch=arm64:NoSchedule taint on Arm node pools).
    node_selector = optional(map(string), {})
    tolerations = optional(list(object({
      key      = optional(string, "")
      operator = optional(string, "Equal")
      value    = optional(string, "")
      effect   = optional(string, "")
    })), [])

    operator = optional(object({
      enabled                    = optional(bool, false)
      chart_version              = optional(string, "0.120.0")
      collector_image_repository = optional(string, "otel/opentelemetry-collector-k8s")
      cert_manager_enabled       = optional(bool, false)
      auto_generate_cert_enabled = optional(bool, true)
      extra_args                 = optional(list(string), [])

      # Go auto-instrumentation (eBPF-based; requires Linux kernel >=4.19 and privileged DaemonSet)
      go_instrumentation_enabled = optional(bool, false)
      go_instrumentation_image   = optional(string, "") # defaults to chart appVersion image when empty
    }), {})

    # Optional Kafka buffering (see modules/kafka-gke). When `brokers` is set and
    # `role` is producer/consumer the metrics/logs/traces pipelines are rewired:
    #   producer -> pipeline exporters become kafka/{metrics,logs,traces} (this
    #     collector ships OTLP to the topics instead of the backends directly);
    #   consumer -> pipeline receivers become kafka/{metrics,logs,traces} with a
    #     lean processor set, draining the topics into the backend exporters
    #     (which stay wired from tempo_/mimir2_/loki_endpoint).
    # role "" (default) => Kafka off, direct writes as before.
    kafka = optional(object({
      brokers        = optional(string, "") # bootstrap host:port (comma-sep ok); "" disables
      role           = optional(string, "") # producer | consumer | ""
      metrics_topic  = optional(string, "otlp_metrics")
      logs_topic     = optional(string, "otlp_logs")
      traces_topic   = optional(string, "otlp_traces")
      encoding       = optional(string, "otlp_proto")
      consumer_group = optional(string, "otel-consumer")
      # producer kafka-exporter max_message_bytes; keep >= broker/topic
      # max.message.bytes or large batches fail with MESSAGE_TOO_LARGE.
      max_message_bytes = optional(number, 1000000)
    }), {})
  })
  default = {}

  validation {
    condition     = contains(["daemonset", "deployment"], var.otel.mode)
    error_message = "mode must be one of: daemonset, deployment."
  }

  validation {
    condition     = contains(["", "producer", "consumer"], var.otel.kafka.role)
    error_message = "otel.kafka.role must be one of: \"\", producer, consumer."
  }

  validation {
    condition     = contains(["otlp_proto", "otlp_json"], var.otel.kafka.encoding)
    error_message = "otel.kafka.encoding must be otlp_proto or otlp_json (the OTLP payload encodings for the kafka exporter/receiver)."
  }

  validation {
    condition     = var.otel.clickhouse_credentials_secret == null || (var.otel.clickhouse_username == "" && var.otel.clickhouse_password == "")
    error_message = "clickhouse_credentials_secret is mutually exclusive with clickhouse_username/clickhouse_password — set one or the other, not both."
  }
}
