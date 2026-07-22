# Kafka-buffered example: two OpenTelemetry Collectors around a Kafka broker.
#
#   apps ── OTLP ──▶ otel (producer) ── Kafka ──▶ otel-consumer ──▶ Tempo/Mimir/Loki
#
# The producer collector receives OTLP from your apps and ships it to Kafka
# topics instead of writing to the backends directly. The consumer collector
# drains those topics and writes to Tempo/Mimir/Loki. Kafka absorbs backend
# outages and traffic spikes so producers never block.
#
# The Kafka broker is NOT created here — supply an existing bootstrap address via
# `kafka_brokers` (e.g. Strimzi, MSK, Confluent, or the AxonOps Kafka operator).
# Backends use local-disk storage to keep the example self-contained; swap in
# S3/GCS/Azure for production (see examples/aws, examples/gcp).

module "cert_manager" {
  source       = "../../modules/cert-manager"
  cert_manager = var.cert_manager
}

module "mimir" {
  source = "../../modules/mimir"
  mimir  = var.mimir
}

module "prometheus" {
  source = "../../modules/prometheus"
  prometheus = merge(var.prometheus, {
    # Mimir already created the monitoring namespace; skip re-creation.
    create_namespace         = false
    mimir_remote_write_url   = module.mimir.remote_write_endpoint
    mimir_datasource_url     = module.mimir.query_frontend_endpoint
    mimir_tenant_id          = module.mimir.tenant_id
    loki_datasource_url      = module.loki.datasource_url
    tempo_datasource_url     = module.tempo.datasource_url
    pyroscope_datasource_url = module.pyroscope.datasource_url
    grafana_ingress = {
      enabled = true
      host    = "grafana.${var.ingress_domain}"
    }
  })
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

module "pyroscope" {
  source = "../../modules/pyroscope"
  pyroscope = merge(var.pyroscope, {
    create_namespace = false
  })
}

# Producer: apps send OTLP here; it ships to the Kafka topics instead of the
# backends. Keep the default release name ("otel") so its OTLP service endpoint
# is otel-opentelemetry-collector.<ns>.svc — the address you instrument against.
module "otel_producer" {
  source = "../../modules/otel-collector"
  otel = merge(var.otel, {
    create_namespace = false
    release_name     = "otel"
    kafka = {
      brokers     = var.kafka_brokers
      role        = "producer"
      compression = "zstd" # keep large log batches under max.message.bytes
    }
  })
}

# Consumer: drains the Kafka topics and writes to the backends. Runs as a
# separate release so it scales independently of the producer.
module "otel_consumer" {
  source = "../../modules/otel-collector"
  otel = merge(var.otel, {
    create_namespace = false
    release_name     = "otel-consumer"
    tempo_endpoint   = module.tempo.otlp_grpc_endpoint
    mimir_endpoint   = module.mimir.remote_write_endpoint
    loki_endpoint    = module.loki.datasource_url
    kafka = {
      brokers = var.kafka_brokers
      role    = "consumer"
    }
  })
}

module "prometheus_rules" {
  source = "../../modules/prometheus-rules"
  prometheus_rules = merge(var.prometheus_rules, {
    namespace             = try(var.prometheus.namespace, "monitoring")
    prometheus_release_id = module.prometheus.helm_release_id
  })
}

module "grafana_rules" {
  source = "../../modules/grafana-rules"
  grafana_rules = merge(var.grafana_rules, {
    namespace = try(var.prometheus.namespace, "monitoring")
  })
}

output "otlp_grpc_endpoint" {
  description = "OTLP gRPC endpoint for app instrumentation (producer collector → Kafka)."
  value       = module.otel_producer.otlp_grpc_endpoint
}

output "grafana_service" {
  description = "In-cluster Grafana service URL."
  value       = module.prometheus.grafana_service
}

output "kafka_brokers" {
  description = "Kafka bootstrap address the collectors produce to / consume from."
  value       = var.kafka_brokers
}
