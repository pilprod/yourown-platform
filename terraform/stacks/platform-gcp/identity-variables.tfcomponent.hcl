variable "workload_identities" {
  description = "Logical workload identities; products supply account names, Kubernetes bindings and explicit project roles privately. Kubernetes service accounts are owned by their runtime."
  type = map(object({
    account_id    = string
    display_name  = optional(string, "Platform workload identity")
    description   = optional(string, "")
    project_roles = optional(set(string), [])
    kubernetes_service_accounts = optional(set(object({
      namespace = string
      name      = string
    })), [])
  }))
  default = {}
}
