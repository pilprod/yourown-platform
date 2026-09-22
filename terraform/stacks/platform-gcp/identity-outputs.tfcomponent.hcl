output "workload_identities" {
  description = "Private identity handoff for product/runtime bindings."
  type = map(object({
    email  = string
    member = string
  }))
  value = {
    for name, identity in component.workload_identity : name => {
      email  = identity.email
      member = identity.iam_email
    }
  }
  sensitive = true
}
