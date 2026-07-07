# Grafana external DB referencing an existing Secret — the module must NOT
# create its own Secret (password_secret path); the password is injected from
# the caller-managed Secret via secretKeyRef.
prometheus = {
  grafana_database = {
    type            = "postgres"
    host            = "pg.db.svc:5432"
    name            = "grafana"
    user            = "grafana"
    password_secret = { name = "grafana-db", field = "password" }
  }
}
