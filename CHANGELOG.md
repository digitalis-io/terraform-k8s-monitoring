# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `modules/prometheus`: Tempo→Pyroscope **Trace to profiles** correlation. The Tempo Grafana datasource now gets a `tracesToProfiles` block linking a span to its CPU profile in Pyroscope (matched by `service.name`). New `tempo_profile_type_id` variable (default `"process_cpu:cpu:nanoseconds:cpu:nanoseconds"`) selects the default profile type; set `""` to disable. Active only when both `tempo_datasource_url` and `pyroscope_datasource_url` are set.
- `modules/prometheus`: Loki→Tempo log↔trace correlation. The Loki Grafana datasource now gets a `derivedFields` entry that links each log line's trace id to the trace in Tempo (a **View trace** link), complementing the existing Tempo→Loki `tracesToLogsV2` wiring. The Tempo datasource is given a stable `uid: tempo`. New `loki_trace_id_field` variable (default `"trace_id"`) names the trace-id field in the JSON log body; set `""` to disable. Active only when both `loki_datasource_url` and `tempo_datasource_url` are set.
- `modules/otel-collector`: `log_parsing` object variable to configure structured-log parsing on the daemonset `filelog` receiver. New fields `json_enabled`, `json_match_expr`, `severity_field`, `trace_enabled`, `trace_id_field`, `span_id_field` allow you to match your application's log field names and disable parsing entirely if needed. Defaults preserve the built-in JSON detection (`^\\s*[{]`) and field names (`trace_id`, `span_id`, `level`).
- `modules/alloy`: new module — Grafana Alloy collector (daemonset/deployment/statefulset) with River/Alloy pipeline config, sibling-module integration hooks for Loki, Tempo, Mimir, Pyroscope, and OTel Collector, and WAL persistence support for statefulset mode.
- `examples/alloy-basic`: minimal example wiring Alloy as a daemonset collector forwarding OTLP signals to Loki, Tempo, and Mimir.
- `modules/otel-collector`: ClickHouse exporter support via new `clickhouse_endpoint`, `clickhouse_username`, `clickhouse_password`, `clickhouse_database`, and `clickhouse_create_schema` variables. Logs and traces can now be forwarded to ClickHouse alongside (or instead of) Loki/Tempo.
- `modules/otel-collector`: OpenTelemetry Operator support via new `operator` object variable (opt-in; `operator.enabled` defaults to `false`). When enabled, deploys the OTel Operator Helm chart which provides `OpenTelemetryCollector` and `Instrumentation` CRDs. Includes optional Go eBPF auto-instrumentation support (`operator.go_instrumentation_enabled`; requires Linux kernel ≥ 4.19).
- `modules/otel-collector`: Host metrics collection for daemonset mode — `hostmetrics` receiver added to the metrics pipeline when `mode = "daemonset"`.
- `modules/otel-collector`: `mimir_tenant_id` variable to set the `X-Scope-OrgID` header on remote-write requests, matching the Mimir multi-tenancy configuration.
- `modules/prometheus`: ClickHouse datasource support in Grafana via new `clickhouse_datasource` object variable. Configures the `grafana-clickhouse-datasource` plugin with OTel schema table references for logs and traces.
- `modules/prometheus`: `grafana_plugins` variable to control which Grafana plugins are installed. Defaults include common community plugins; ClickHouse datasource plugin included.
- `modules/tempo`: `metrics_generator_remote_write_url` variable to enable the Tempo metrics generator for `rate()` and span metrics. Set to the Mimir remote-write URL to activate; empty string disables the generator (default).

### Changed

- `modules/otel-collector`: Chart version updated from `0.150.0` to `0.158.2`.
- `modules/otel-collector`: Default resource requests increased from `100m CPU / 128Mi` to `300m CPU / 256Mi` to support hostmetrics collection alongside traces and logs.
- `modules/prometheus`: Chart version (`kube-prometheus-stack`) updated from `75.2.0` to `86.3.2`.
- `modules/prometheus`: Grafana `tracesToMetrics.datasourceUid` corrected from `"Mimir"` (display name) to `"mimir"` (UID) — fixes broken request-rate and latency links in the Tempo trace view.
- `modules/otel-collector`: `helm_release` values wrapped in `sensitive()` to suppress ClickHouse credentials from plan output. Credentials remain in Terraform state; ensure your state backend encrypts at rest.
- `modules/prometheus`: `helm_release` values wrapped in `sensitive()` to suppress ClickHouse datasource password from plan output.
- `modules/mimir`: `ingress_host` validation now enforces RFC 1123 hostname format in addition to requiring a non-empty value when `ingress_enabled = true`.
- `modules/prometheus`: `grafana_ingress.host`, `prometheus_ingress.host`, and `alertmanager_ingress.host` validation now enforces RFC 1123 hostname format when the respective ingress is enabled.

### Fixed

- `modules/prometheus`: fixed the Loki→Tempo **View trace** derived field opening Tempo with an empty query. Two causes: (1) `matcherType: label` does not resolve a value for OTLP structured-metadata fields in the Grafana Logs Drilldown app — switched to a regex matcher against the JSON log body (`"<field>":"(\w+)"`); and (2) the derived-field `url` was emitted as `${__value.raw}`, which Grafana's provisioning-file `$`-interpolation consumes at load time (storing an empty `url`) — it is now emitted as `$${__value.raw}` (a triple-`$` in the template, which `templatefile()` collapses to the required double-`$`) so Grafana stores the literal `${__value.raw}` and substitutes the captured trace id at click time. Fixes [#12](https://github.com/digitalis-io/terraform-k8s-monitoring/issues/12).
- `modules/otel-collector`: the `filelog` receiver (daemonset mode) now parses structured JSON pod logs and promotes `trace_id`/`span_id` into native OTel fields. Guarded JSON and trace parsers populate ClickHouse `otel_logs.TraceId`/`SpanId`/`SeverityText`, enabling native log↔trace correlation without `JSONExtractString(Body, …)` and supporting Grafana logs↔traces linking. Fixes [#10](https://github.com/digitalis-io/terraform-k8s-monitoring/issues/10).
- `local-exec` kubectl provisioners in `modules/cert-manager` and `modules/prometheus-rules` no longer hardcode `$HOME/.kube/config` as the kubeconfig fallback. When `kubeconfig_path` is empty, `--kubeconfig` is omitted entirely so kubectl uses its standard resolution order (`KUBECONFIG` env var → `~/.kube/config`). Fixes terraform apply failures when `$HOME/.kube/config` does not exist.
