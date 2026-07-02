# Faro receiver enabled — exercises the built-in faro.receiver config path.
# release_name is intentionally left at its default here: the shared
# tests/compliance/features/alloy/helm_release.feature asserts the release is
# named "alloy" and runs against this plan too. release_name override
# coverage lives in terratest (TestAlloyModuleValidateCustomReleaseName,
# TestAlloyCoexistsWithSecondFaroReceiverInstance), not the compliance layer.
alloy = {
  controller_type = "deployment"
  replicas        = 2
  faro_receiver   = { enabled = true }
  tempo_endpoint  = "http://tempo.monitoring.svc.cluster.local:4317"
  loki_endpoint   = "http://loki.monitoring.svc.cluster.local:3100"
}
