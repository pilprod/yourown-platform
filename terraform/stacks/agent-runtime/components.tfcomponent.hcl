component "cluster_auth" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version = "45.0.0"
  inputs = {
    project_id           = var.target.project_id
    location             = var.target.cluster_location
    cluster_name         = var.target.cluster_name
    use_private_endpoint = true
  }
  providers = { google = provider.google.target }
}

component "gateway_api" {
  for_each = length(var.runtime.agentgateway) > 0 ? toset(["standard"]) : toset([])
  source   = "../../modules/runtime/gateway-api"
  providers = {
    http       = provider.http.releases
    kubernetes = provider.kubernetes.runtime
  }
}

component "agentgateway" {
  for_each = var.runtime.agentgateway
  source   = "../../modules/runtime/agentgateway"
  inputs   = { config = each.value }
  providers = {
    helm       = provider.helm.runtime
    kubernetes = provider.kubernetes.runtime
  }
  depends_on = [component.gateway_api]
}

component "temporal" {
  for_each = var.runtime.temporal
  source   = "../../modules/runtime/temporal"
  inputs   = { config = each.value }
  providers = {
    helm       = provider.helm.runtime
    kubernetes = provider.kubernetes.runtime
  }
}
