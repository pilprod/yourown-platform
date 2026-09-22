output "cluster" {
  description = "Private handoff to the separately owned runtime Stack; null when GKE is disabled."
  type = object({
    name                 = string
    location             = string
    workload_pool        = string
    endpoint             = string
    ca_certificate       = string
    node_service_account = string
    node_pool_names      = list(string)
  })
  value = var.gke == null ? null : {
    name                 = component.cluster["enabled"].name
    location             = component.cluster["enabled"].location
    workload_pool        = component.cluster["enabled"].identity_namespace
    endpoint             = component.cluster["enabled"].endpoint
    ca_certificate       = component.cluster["enabled"].ca_certificate
    node_service_account = component.node_identity["enabled"].email
    node_pool_names      = component.cluster["enabled"].node_pools_names
  }
  sensitive = true
}

output "registries" {
  description = "Private repository identifiers and image prefixes keyed by logical identity."
  type = map(object({
    id  = string
    url = string
  }))
  value = { for key, registry in component.registry : key => {
    id  = registry.id
    url = registry.url
  } }
  sensitive = true
}

output "reserved_addresses" {
  description = "Private address handoff for separately owned ingress and edge resources."
  type = map(object({
    name      = string
    address   = string
    self_link = string
  }))
  value = { for key, reservation in component.reserved_address : key => {
    name      = one(reservation.names)
    address   = one(reservation.addresses)
    self_link = one(reservation.self_links)
  } }
  sensitive = true
}

output "nat_address" {
  description = "Reserved outbound address; null when NAT is disabled or uses automatic allocation."
  type        = string
  value       = try(one(component.nat_address["enabled"].addresses), null)
  sensitive   = true
}

output "network" {
  description = "Private network identifiers for separately owned resources."
  type = object({
    id     = string
    subnet = string
  })
  value = {
    id     = component.network.network_id
    subnet = component.network.subnets["${var.target.region}/${var.target.name}-subnet"].self_link
  }
  sensitive = true
}
