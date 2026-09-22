output "contract" {
  description = "Application delivery owns its namespace, Gateway resources and namespaced deployer RoleBinding."
  value = {
    namespace            = var.config.namespace
    service_account_name = var.config.service_account_name
    deployer_role_name   = local.deployer_role
    controller_release   = helm_release.controller.name
    crd_release          = helm_release.crds.name
    chart_version        = local.chart_version
  }
}
