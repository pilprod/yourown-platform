locals {
  chart_version = "1.2.0"
  tls_mount     = { name = "database-ca", mountPath = "/etc/temporal/database-ca", readOnly = true }
  tls_volume = {
    name = "database-ca"
    secret = {
      secretName = var.config.database.tls.ca_secret_name
      items      = [{ key = var.config.database.tls.ca_secret_key, path = "ca.crt" }]
    }
  }
  database_tls = {
    enabled                = true
    enableHostVerification = true
    serverName             = var.config.database.tls.server_name
    caFile                 = "/etc/temporal/database-ca/ca.crt"
  }
  stores = {
    default    = var.config.database.default_store
    visibility = var.config.database.visibility_store
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name   = var.config.namespace
    labels = var.config.labels
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  metadata {
    name      = var.config.release_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec { hard = var.config.quota }
}

resource "kubernetes_limit_range_v1" "this" {
  metadata {
    name      = var.config.release_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    limit {
      type            = "Container"
      default         = var.config.resources.limits
      default_request = var.config.resources.requests
    }
  }
}

resource "kubernetes_network_policy_v1" "this" {
  metadata {
    name      = var.config.release_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = var.config.namespace }
        }
      }
    }
    dynamic "ingress" {
      for_each = var.config.client_namespaces
      content {
        from {
          namespace_selector {
            match_labels = { "kubernetes.io/metadata.name" = ingress.value }
          }
        }
        ports {
          port     = "7233"
          protocol = "TCP"
        }
      }
    }
    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = var.config.namespace }
        }
      }
    }
    egress {
      to {
        ip_block { cidr = "${var.config.cluster_dns_ip}/32" }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
    egress {
      dynamic "to" {
        for_each = var.config.database.egress_cidrs
        content {
          ip_block { cidr = to.value }
        }
      }
      ports {
        port     = tostring(var.config.database.port)
        protocol = "TCP"
      }
    }
  }
}

resource "helm_release" "this" {
  name             = var.config.release_name
  repository       = "https://go.temporal.io/helm-charts"
  chart            = "temporal"
  version          = local.chart_version
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  create_namespace = false
  values = [yamlencode({
    fullnameOverride = var.config.release_name
    serviceAccount   = { create = true, name = var.config.service_account_name }
    server = {
      enabled                = true
      replicaCount           = var.config.replica_count
      resources              = var.config.resources
      versionCheckDisabled   = true
      frontend               = { service = { type = "ClusterIP", port = 7233 }, ingress = { enabled = false } }
      image                  = { repository = "temporalio/server", tag = "1.31.0@sha256:b021b3b58c3f169634cdbb0451fcc0e69e8190b40454323362c7c52bbd4ff7b9", pullPolicy = "IfNotPresent" }
      additionalVolumes      = [local.tls_volume]
      additionalVolumeMounts = [local.tls_mount]
      config = {
        logLevel = "info"
        persistence = {
          defaultStore     = "default"
          visibilityStore  = "visibility"
          numHistoryShards = var.config.history_shards
          datastores = {
            for name, store in local.stores : name => { sql = {
              createDatabase  = false
              manageSchema    = var.config.database.manage_schema
              pluginName      = "postgres12"
              driverName      = "postgres12"
              databaseName    = store.name
              user            = store.user
              connectAddr     = "${var.config.database.host}:${var.config.database.port}"
              connectProtocol = "tcp"
              existingSecret  = var.config.database.existing_secret_name
              secretKey       = var.config.database.secret_key
              tls             = local.database_tls
            } }
          }
        }
      }
    }
    admintools = {
      enabled                = false
      image                  = { repository = "temporalio/admin-tools", tag = "1.31.0@sha256:3e68adcd54195a7c1222e99f2dbc32a4fdbf44ad69e3bb48e21e85c4bf417c2e", pullPolicy = "IfNotPresent" }
      additionalVolumes      = [local.tls_volume]
      additionalVolumeMounts = [local.tls_mount]
    }
    web = { enabled = false }
    schema = {
      useHelmHooks            = false
      backoffLimit            = 10
      ttlSecondsAfterFinished = 600
      resources               = var.config.resources
    }
    shims = { dockerize = false, elasticsearchTool = false }
  })]
  atomic          = true
  cleanup_on_fail = true
  lint            = true
  reset_values    = true
  reuse_values    = false
  wait            = true
  wait_for_jobs   = true
  timeout         = 900
  max_history     = 5
  depends_on = [
    kubernetes_resource_quota_v1.this,
    kubernetes_limit_range_v1.this,
    kubernetes_network_policy_v1.this,
  ]
}
