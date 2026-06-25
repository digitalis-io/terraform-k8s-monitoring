# Ingress enabled with a valid hostname.
alloy = {
  ingress = {
    enabled    = true
    host       = "alloy.example.com"
    class_name = "nginx"
    tls_secret = "alloy-tls"
  }
}
