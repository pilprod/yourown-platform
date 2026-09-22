variable "target" {
  description = "Private snapshot of the existing cluster; this Stack does not create cloud infrastructure."
  type = object({
    project_id       = string
    region           = string
    cluster_name     = string
    cluster_location = string
  })
}

variable "federation" {
  description = "Private, phase-scoped Google WIF binding for runtime administration."
  type = object({
    audience              = string
    service_account_email = string
  })
}

variable "identity_token" {
  description = "Short-lived identity token supplied privately by the approved runner."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "runtime" {
  description = "Private runtime selection. Empty maps disable a capability; one Stack owns the cluster-wide Gateway APIs."
  type = object({
    agentgateway = map(object({
      namespace            = string
      release_name         = string
      crd_release_name     = string
      service_account_name = string
      discovery_namespaces = set(string)
      controller_replicas  = number
      resources = object({
        requests = object({ cpu = string, memory = string })
        limits   = object({ cpu = string, memory = string })
      })
      labels = map(string)
    }))
    temporal = map(object({
      namespace            = string
      release_name         = string
      service_account_name = string
      replica_count        = number
      history_shards       = number
      client_namespaces    = set(string)
      cluster_dns_ip       = string
      resources = object({
        requests = object({ cpu = string, memory = string })
        limits   = object({ cpu = string, memory = string })
      })
      quota  = map(string)
      labels = map(string)
      database = object({
        host                 = string
        port                 = number
        egress_cidrs         = set(string)
        existing_secret_name = string
        secret_key           = string
        manage_schema        = bool
        default_store        = object({ name = string, user = string })
        visibility_store     = object({ name = string, user = string })
        tls = object({
          server_name    = string
          ca_secret_name = string
          ca_secret_key  = string
        })
      })
    }))
  })

  validation {
    condition     = length(var.runtime.agentgateway) <= 1
    error_message = "Only one agentgateway control plane may own the shared Gateway APIs in this Stack."
  }

  validation {
    condition = length(distinct(concat(
      [for runtime in values(var.runtime.agentgateway) : runtime.namespace],
      [for runtime in values(var.runtime.temporal) : runtime.namespace]
    ))) == length(var.runtime.agentgateway) + length(var.runtime.temporal)
    error_message = "Each runtime component must own a distinct namespace."
  }
}
