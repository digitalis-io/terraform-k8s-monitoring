# Grafana Faro real-user-monitoring (RUM) receiver example.
#
# Deploys a minimal Loki + Tempo backend, a standard Alloy DaemonSet collector
# for OTLP-instrumented backend services, and a second Alloy release —
# release_name = "faro-receiver" — configured as a Deployment with
# faro_receiver.enabled = true to accept RUM telemetry (JS errors, traces,
# logs, web-vitals) from the Faro Web SDK running in browsers.
#
# Grafana does not publish a standalone "faro" Helm chart: the Faro receiver
# is Alloy configured with its faro.receiver component. Both Alloy releases
# live in the same namespace without colliding because they use distinct
# Helm release names.
#
# faro.receiver has no metrics output, so only traces (→ Tempo) and logs
# (→ Loki) are forwarded — there is no Mimir wiring for the Faro receiver.
#
# Docs: https://grafana.com/oss/faro/ and https://grafana.com/docs/alloy/

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
  })
}

module "faro_receiver" {
  source = "../../modules/alloy"
  alloy = merge(var.faro_receiver, {
    release_name     = "faro-receiver"
    create_namespace = false
    controller_type  = "deployment"
    faro_receiver    = { enabled = true }
    loki_endpoint    = module.loki.datasource_url
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
  })
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint — point instrumented backend applications here."
  value       = module.alloy.otlp_grpc_endpoint
}

output "otlp_http_endpoint" {
  description = "OTLP HTTP endpoint — point instrumented backend applications here."
  value       = module.alloy.otlp_http_endpoint
}

output "faro_receiver_http_endpoint" {
  description = "In-cluster HTTP endpoint for the Faro Web SDK baseUrl — applications running inside the cluster."
  value       = module.faro_receiver.faro_receiver_http_endpoint
}

output "faro_receiver_public_url" {
  description = "Public HTTP(S) URL for the Faro Web SDK baseUrl — set only when ingress is enabled via var.faro_receiver."
  value       = module.faro_receiver.faro_receiver_public_url
}
