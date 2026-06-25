# All sibling endpoints wired — exercises the built-in River config template.
alloy = {
  loki_endpoint      = "http://loki.monitoring.svc.cluster.local:3100"
  tempo_endpoint     = "http://tempo.monitoring.svc.cluster.local:4317"
  mimir_endpoint     = "http://mimir-nginx.monitoring.svc.cluster.local/api/v1/push"
  mimir_tenant_id    = "anonymous"
  pyroscope_endpoint = "http://pyroscope.monitoring.svc.cluster.local:4040"
  otel_grpc_endpoint = "http://otel.monitoring.svc.cluster.local:4317"
}
