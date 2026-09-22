locals {
  chart_version   = "v1.5.0"
  controller_tag  = "v1.5.0@sha256:319489cb86b7f901a52a3fc532ad07f136c92756f88cf02a4040909e20001120"
  proxy_tag       = "v1.5.0@sha256:bf2f339ef326d32def2aaeb44b1b4549801293c19b89e764a4228667d97d9896"
  controller_role = "agentgateway-${var.config.namespace}"
  deployer_role   = "agentgateway-${var.config.namespace}-deployer"
  local_role      = "agentgateway-${var.config.namespace}-local"
  chart_labels    = { "app.kubernetes.io/part-of" = "yourown-platform" }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.config.namespace
    labels = merge(var.config.labels, {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    })
  }
}

resource "kubernetes_service_account_v1" "controller" {
  metadata {
    name      = var.config.service_account_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.chart_labels
  }
}

resource "helm_release" "crds" {
  name             = var.config.crd_release_name
  chart            = "oci://cr.agentgateway.dev/charts/agentgateway-crds@sha256:3a6cf44559c612ac8afb7f867aace69bbd4cdba765f1def6377b7a3186c603e3"
  version          = local.chart_version
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  create_namespace = false
  atomic           = false
  cleanup_on_fail  = false
  lint             = true
  reset_values     = true
  reuse_values     = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 900
  max_history      = 5

  lifecycle {
    prevent_destroy = true
  }
}

# The upstream controller role includes cluster discovery, status updates,
# GatewayClass reconciliation and TokenReview creation. It is not read-only.
resource "kubernetes_cluster_role_binding_v1" "controller" {
  metadata {
    name   = "agentgateway-controller-${var.config.namespace}"
    labels = local.chart_labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = local.controller_role
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.controller.metadata[0].name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "controller_local" {
  metadata {
    name      = "agentgateway-controller-local"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.chart_labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = local.local_role
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.controller.metadata[0].name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
}

resource "helm_release" "controller" {
  name             = var.config.release_name
  chart            = "oci://cr.agentgateway.dev/charts/agentgateway@sha256:9216ce83965ad2ce0888014d14aac5e71333fd9d4057cd167da92b37630fbee1"
  version          = local.chart_version
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  create_namespace = false
  values = [yamlencode({
    commonLabels = local.chart_labels
    image        = { registry = "cr.agentgateway.dev", tag = local.proxy_tag, pullPolicy = "IfNotPresent" }
    controller = {
      replicaCount = var.config.controller_replicas
      service      = { enabled = true, type = "ClusterIP" }
      logLevel     = "info"
      image = {
        registry   = "cr.agentgateway.dev"
        repository = "controller"
        tag        = local.controller_tag
        pullPolicy = "IfNotPresent"
      }
    }
    proxy              = { image = { registry = "cr.agentgateway.dev", repository = "agentgateway", tag = local.proxy_tag } }
    serviceAccount     = { create = false, name = var.config.service_account_name }
    agentgatewayModels = { enabled = false }
    inferenceExtension = { enabled = false }
    discoveryNamespaceSelectors = [
      for namespace in sort(tolist(setunion(var.config.discovery_namespaces, toset([var.config.namespace])))) :
      { matchLabels = { "kubernetes.io/metadata.name" = namespace } }
    ]
    podSecurityContext = { runAsNonRoot = true, seccompProfile = { type = "RuntimeDefault" } }
    securityContext = {
      allowPrivilegeEscalation = false
      capabilities             = { drop = ["ALL"] }
      readOnlyRootFilesystem   = true
      runAsNonRoot             = true
    }
    resources = var.config.resources
  })]
  atomic          = true
  cleanup_on_fail = true
  skip_crds       = true
  lint            = true
  reset_values    = true
  reuse_values    = false
  wait            = true
  wait_for_jobs   = true
  timeout         = 900
  max_history     = 5

  # Bindings may name chart-created roles before those roles exist. Creating them
  # before Helm waits avoids a readiness cycle with the controller installation.
  depends_on = [
    helm_release.crds,
    kubernetes_cluster_role_binding_v1.controller,
    kubernetes_role_binding_v1.controller_local,
  ]
}
