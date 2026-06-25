# Grafana Alloy basic example.
#
# Deploys Alloy as a DaemonSet collector alongside minimal Loki, Tempo, and Mimir
# deployments. Alloy receives OTLP signals from instrumented applications on ports
# 4317 (gRPC) and 4318 (HTTP) and forwards:
#   - Traces  → Tempo
#   - Logs    → Loki
#   - Metrics → Mimir
#
# Alloy is the OpenTelemetry-native successor to Grafana Agent.
# Docs: https://grafana.com/docs/alloy/

module "mimir" {
  source = "../../modules/mimir"
  mimir  = var.mimir
}

module "loki" {
  source = "../../modules/loki"
  loki = merge(var.loki, {
    create_namespace = false
  })
}

module "tempo" {
  source = "../../modules/tempo"
  tempo = merge(var.tempo, {
    create_namespace = false
  })
}

module "alloy" {
  source = "../../modules/alloy"
  alloy = merge(var.alloy, {
    create_namespace = false
    loki_endpoint    = module.loki.datasource_url
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    mimir_tenant_id  = module.mimir.tenant_id
  })
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint — point instrumented applications here."
  value       = module.alloy.otlp_grpc_endpoint
}

output "otlp_http_endpoint" {
  description = "OTLP HTTP endpoint — point instrumented applications here."
  value       = module.alloy.otlp_http_endpoint
}
