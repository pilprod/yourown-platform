variable "config" {
  description = "Private Temporal runtime capacity and existing PostgreSQL/secret references. No secret values are accepted."
  type = object({
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
  })

  validation {
    condition = alltrue([
      for name in concat([var.config.namespace, var.config.service_account_name], tolist(var.config.client_namespaces)) :
      length(name) <= 63 && can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name))
    ])
    error_message = "Namespace and service-account names must be valid DNS labels."
  }

  validation {
    condition = (var.config.replica_count >= 1 && floor(var.config.replica_count) == var.config.replica_count &&
    var.config.history_shards >= 1 && floor(var.config.history_shards) == var.config.history_shards)
    error_message = "Replica count and the immutable history shard count must be positive integers."
  }

  validation {
    condition = (length(var.config.database.egress_cidrs) > 0 && alltrue([
      for cidr in var.config.database.egress_cidrs : can(cidrhost(cidr, 0))
      ]) && can(cidrhost("${var.config.cluster_dns_ip}/32", 0)) &&
    var.config.database.port >= 1 && var.config.database.port <= 65535 && floor(var.config.database.port) == var.config.database.port)
    error_message = "Database egress CIDRs, a cluster DNS address and a valid database port are required."
  }

  validation {
    condition = alltrue([
      for value in [var.config.database.host, var.config.database.existing_secret_name, var.config.database.secret_key,
        var.config.database.tls.server_name, var.config.database.tls.ca_secret_name, var.config.database.tls.ca_secret_key,
        var.config.database.default_store.name, var.config.database.default_store.user,
      var.config.database.visibility_store.name, var.config.database.visibility_store.user] : length(trimspace(value)) > 0
    ]) && var.config.database.default_store.name != var.config.database.visibility_store.name
    error_message = "Distinct database stores and explicit host, identity, credential-secret and verified TLS references are required."
  }
}
