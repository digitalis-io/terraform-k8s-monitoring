# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `local-exec` kubectl provisioners in `modules/cert-manager` and `modules/prometheus-rules` no longer hardcode `$HOME/.kube/config` as the kubeconfig fallback. When `kubeconfig_path` is empty, `--kubeconfig` is omitted entirely so kubectl uses its standard resolution order (`KUBECONFIG` env var → `~/.kube/config`). Fixes terraform apply failures when `$HOME/.kube/config` does not exist.

### Changed

- `modules/mimir`: `ingress_host` validation now enforces RFC 1123 hostname format in addition to requiring a non-empty value when `ingress_enabled = true`.
- `modules/prometheus`: `grafana_ingress.host`, `prometheus_ingress.host`, and `alertmanager_ingress.host` validation now enforces RFC 1123 hostname format when the respective ingress is enabled.
