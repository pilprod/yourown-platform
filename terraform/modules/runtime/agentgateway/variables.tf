variable "config" {
  description = "Private control-plane names, selected discovery namespaces and explicit capacity."
  type = object({
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
  })

  validation {
    condition = alltrue([
      for name in concat([var.config.namespace, var.config.service_account_name], tolist(var.config.discovery_namespaces)) :
      length(name) <= 63 && can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name))
    ])
    error_message = "Namespace and service-account names must be valid DNS labels."
  }

  validation {
    condition     = var.config.controller_replicas >= 1 && floor(var.config.controller_replicas) == var.config.controller_replicas
    error_message = "The controller replica count must be a positive integer."
  }

  validation {
    condition = var.config.release_name != var.config.crd_release_name && alltrue([
      for name in [var.config.release_name, var.config.crd_release_name] :
      length(name) <= 53 && can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name))
    ])
    error_message = "Controller and CRD release names must be distinct valid Helm release names."
  }
}
