# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

- `modules/otel-collector`: the `filelog` receiver (daemonset mode) now parses structured JSON pod logs and promotes their trace context to native OTel fields. A guarded `json_parser` populates `SeverityText` from the JSON `level` and lifts fields into log attributes (plain-text logs pass through untouched), and a guarded `trace_parser` promotes `trace_id`/`span_id` into the record's trace context. This fills the ClickHouse `otel_logs.TraceId`/`SpanId` columns, enabling native log↔trace correlation without `JSONExtractString(Body, …)`. Fixes [#10](https://github.com/digitalis-io/terraform-k8s-monitoring/issues/10).
- `local-exec` kubectl provisioners in `modules/cert-manager` and `modules/prometheus-rules` no longer hardcode `$HOME/.kube/config` as the kubeconfig fallback. When `kubeconfig_path` is empty, `--kubeconfig` is omitted entirely so kubectl uses its standard resolution order (`KUBECONFIG` env var → `~/.kube/config`). Fixes terraform apply failures when `$HOME/.kube/config` does not exist.
