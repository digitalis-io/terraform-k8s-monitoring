# Ingress enabled with a valid hostname. The chart's ingress feature only ever
# routes to the Faro receiver port, so ingress requires faro_receiver.enabled.
alloy = {
  controller_type = "deployment"
  replicas        = 2
  faro_receiver   = { enabled = true }
  ingress = {
    enabled    = true
    host       = "alloy.example.com"
    class_name = "nginx"
    tls_secret = "alloy-tls"
  }
}
