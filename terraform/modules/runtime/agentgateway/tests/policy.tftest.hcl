mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  config = {
    namespace            = "control-plane"
    release_name         = "gateway-controller"
    crd_release_name     = "gateway-crds"
    service_account_name = "gateway-controller"
    discovery_namespaces = ["agents"]
    controller_replicas  = 1
    resources = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits   = { cpu = "500m", memory = "512Mi" }
    }
    labels = {}
  }
}

run "namespace_and_image_boundaries" {
  command = plan

  assert {
    condition = toset([
      for selector in yamldecode(helm_release.controller.values[0]).discoveryNamespaceSelectors :
      selector.matchLabels["kubernetes.io/metadata.name"]
    ]) == toset(["agents", "control-plane"])
    error_message = "Controller discovery must be limited to explicitly selected namespaces."
  }

  assert {
    condition = (kubernetes_role_binding_v1.controller_local.metadata[0].namespace == "control-plane" &&
    kubernetes_role_binding_v1.controller_local.role_ref[0].kind == "Role")
    error_message = "Local controller writes must use a namespaced role."
  }

  assert {
    condition = alltrue([
      for value in [yamldecode(helm_release.controller.values[0]).controller.image.tag,
      yamldecode(helm_release.controller.values[0]).proxy.image.tag] : can(regex("@sha256:[a-f0-9]{64}$", value))
    ]) && yamldecode(helm_release.controller.values[0]).controller.service.type == "ClusterIP" && helm_release.controller.skip_crds && !yamldecode(helm_release.controller.values[0]).serviceAccount.create
    error_message = "Charts must use immutable images and existing service-account/CRD ownership."
  }
}

run "reject_zero_controller_capacity" {
  command = plan
  variables { config = merge(var.config, { controller_replicas = 0 }) }
  expect_failures = [var.config]
}
