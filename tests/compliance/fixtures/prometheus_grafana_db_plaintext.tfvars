# Grafana external DB with a plaintext password — the module must plan a
# managed Secret (prometheus-grafana-db) to hold it.
# NOTE: this value is a throwaway test placeholder, not a real credential.
prometheus = {
  grafana_replicas = 2
  grafana_database = {
    type     = "postgres"
    host     = "pg.db.svc:5432"
    name     = "grafana"
    user     = "grafana"
    ssl_mode = "require"
    password = "fixture-placeholder-not-a-secret"
  }
}
