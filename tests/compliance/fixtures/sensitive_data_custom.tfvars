# Sensitive-data processor with custom rules overriding/extending the defaults.
alloy = {
  sensitive_data = {
    action = "hash"
    salt   = "test-salt"
    custom_rules = {
      "user.ssn"       = "delete"
      "transaction.id" = "hash"
    }
  }
}
