output "contract" {
  value = {
    namespace     = var.config.namespace
    release_name  = helm_release.this.name
    frontend_host = "${var.config.release_name}-frontend.${var.config.namespace}.svc.cluster.local"
    frontend_port = 7233
    chart_version = local.chart_version
  }
}
