mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  config = {
    namespace            = "workflow-runtime"
    release_name         = "workflow-server"
    service_account_name = "workflow-server"
    replica_count        = 1
    history_shards       = 4
    client_namespaces    = ["workers"]
    cluster_dns_ip       = join(".", ["192", "0", "2", "10"])
    resources = {
      requests = { cpu = "100m", memory = "256Mi" }
      limits   = { cpu = "500m", memory = "512Mi" }
    }
    quota  = { pods = "20" }
    labels = {}
    database = {
      host                 = "database.invalid"
      port                 = 5432
      egress_cidrs         = ["${join(".", ["192", "0", "2", "0"])}/24"]
      existing_secret_name = "workflow-database"
      secret_key           = "password"
      manage_schema        = true
      default_store        = { name = "workflows", user = "workflow_runtime" }
      visibility_store     = { name = "visibility", user = "workflow_runtime" }
      tls = {
        server_name    = "database.invalid"
        ca_secret_name = "database-ca"
        ca_secret_key  = "ca.crt"
      }
    }
  }
}

run "database_and_worker_boundaries" {
  command = plan
  assert {
    condition = alltrue([
      for store in values(yamldecode(helm_release.this.values[0]).server.config.persistence.datastores) :
      store.sql.existingSecret == "workflow-database" && !contains(keys(store.sql), "password") &&
      store.sql.tls.enabled && store.sql.tls.enableHostVerification && !store.sql.createDatabase
    ])
    error_message = "Database configuration must use existing credentials and verified TLS without creating databases."
  }

  assert {
    condition     = yamldecode(helm_release.this.values[0]).server.additionalVolumes == yamldecode(helm_release.this.values[0]).admintools.additionalVolumes
    error_message = "Server and schema jobs must mount the same CA reference, with no public frontend."
  }

  assert {
    condition = anytrue([
      for rule in kubernetes_network_policy_v1.this.spec[0].ingress :
      anytrue([for source in rule.from : source.namespace_selector[0].match_labels["kubernetes.io/metadata.name"] == "workers"]) &&
      anytrue([for port in rule.ports : port.port == "7233"])
    ])
    error_message = "Configured worker namespaces must reach only the declared frontend port."
  }
}

run "reject_missing_tls_identity" {
  command = plan
  variables {
    config = merge(var.config, {
      database = merge(var.config.database, {
        tls = merge(var.config.database.tls, { server_name = "" })
      })
    })
  }
  expect_failures = [var.config]
}
