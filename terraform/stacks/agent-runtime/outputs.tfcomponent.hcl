output "agentgateway" {
  type = map(object({
    namespace            = string
    service_account_name = string
    deployer_role_name   = string
    controller_release   = string
    crd_release          = string
    chart_version        = string
  }))
  description = "Private integration contracts; application delivery owns its namespace and deployer RoleBinding."
  value       = { for name, runtime in component.agentgateway : name => runtime.contract }
  sensitive   = true
}

output "temporal" {
  type = map(object({
    namespace     = string
    release_name  = string
    frontend_host = string
    frontend_port = number
    chart_version = string
  }))
  description = "Private runtime service references, without database credentials."
  value       = { for name, runtime in component.temporal : name => runtime.contract }
  sensitive   = true
}
