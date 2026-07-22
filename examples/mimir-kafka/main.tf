# Mimir with the Kafka ingest-storage backend (Mimir 3.x write path).
#
#   Prometheus ──remote_write──▶ Mimir distributor ──▶ Kafka ──▶ Mimir ingester ──▶ blocks (local disk)
#
# https://grafana.com/docs/mimir/latest/configure/configure-kafka-backend/
#
# In the ingest-storage architecture the distributor writes incoming series to a
# Kafka topic; ingesters consume the topic and build blocks. Kafka becomes the
# durable write-ahead buffer, decoupling ingest from ingesters.
#
# By default this deploys the chart's BUNDLED demo Kafka (self-contained, single
# broker — not for production). Set `kafka_broker` to an existing broker's
# bootstrap address to use your own (Strimzi, MSK, Confluent, AxonOps, …).
#
# Blocks use local-disk storage to keep the example self-contained; swap in
# S3/GCS/Azure for production (see examples/aws, examples/gcp).

module "mimir" {
  source = "../../modules/mimir"
  mimir = merge(var.mimir, {
    kafka_ingest = {
      enabled = true
      # "" → bundled demo Kafka; set kafka_broker to point at an external broker.
      address = var.kafka_broker
      # Partition count must be >= the max ingester replicas in a zone.
      partitions = var.kafka_partitions
    }
  })
}

module "prometheus" {
  source = "../../modules/prometheus"
  prometheus = merge(var.prometheus, {
    # Mimir already created the monitoring namespace; skip re-creation.
    create_namespace       = false
    mimir_remote_write_url = module.mimir.remote_write_endpoint
    mimir_datasource_url   = module.mimir.query_frontend_endpoint
    mimir_tenant_id        = module.mimir.tenant_id
  })
}

output "remote_write_endpoint" {
  description = "Prometheus remote_write URL (writes flow through Kafka into Mimir)."
  value       = module.mimir.remote_write_endpoint
}

output "query_frontend_endpoint" {
  description = "Grafana datasource / query URL for Mimir."
  value       = module.mimir.query_frontend_endpoint
}

output "grafana_service" {
  description = "In-cluster Grafana service URL."
  value       = module.prometheus.grafana_service
}

output "kafka_backend" {
  description = "Kafka broker backing Mimir ingest storage (bundled demo Kafka when kafka_broker is empty)."
  value       = var.kafka_broker != "" ? var.kafka_broker : "bundled demo Kafka (mimir-kafka.${try(var.mimir.namespace, "monitoring")}.svc:9092)"
}
