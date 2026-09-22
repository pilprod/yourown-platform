component "workload_identity" {
  for_each = var.workload_identities
  source   = "terraform-google-modules/service-accounts/google"
  version  = "5.0.0"
  inputs = {
    project_id      = var.target.project_id
    names           = [each.value.account_id]
    display_name    = each.value.display_name
    description     = each.value.description
    project_roles   = [for role in each.value.project_roles : "${var.target.project_id}=>${role}"]
    grant_xpn_roles = false
    generate_keys   = false
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis]
}

component "workload_identity_bindings" {
  for_each = { for name, identity in var.workload_identities : name => identity if length(identity.kubernetes_service_accounts) > 0 }
  source   = "terraform-google-modules/iam/google//modules/service_accounts_iam"
  version  = "8.2.0"
  inputs = {
    project          = var.target.project_id
    service_accounts = ["${lower(each.value.account_id)}@${var.target.project_id}.iam.gserviceaccount.com"]
    mode             = "additive"
    bindings = {
      "roles/iam.workloadIdentityUser" = [
        for account in each.value.kubernetes_service_accounts :
        "serviceAccount:${var.target.project_id}.svc.id.goog[${account.namespace}/${account.name}]"
      ]
    }
  }
  providers  = { google = provider.google.target }
  depends_on = [component.workload_identity, component.cluster]
}
