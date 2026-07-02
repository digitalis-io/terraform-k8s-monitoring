# All sibling endpoints wired — exercises the built-in faro.receiver config template.
faro_receiver = {
  tempo_endpoint = "http://tempo.monitoring.svc.cluster.local:4317"
  loki_endpoint  = "http://loki.monitoring.svc.cluster.local:3100"
}
