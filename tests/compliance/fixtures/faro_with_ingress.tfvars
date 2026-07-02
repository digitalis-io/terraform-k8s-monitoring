# Ingress enabled with a valid hostname.
faro_receiver = {
  ingress = {
    enabled    = true
    host       = "faro.example.com"
    class_name = "nginx"
    tls_secret = "faro-tls"
  }
}
