locals {
  release_version = "v1.6.0"
  release_sha256  = "a557172e8348f758479e9ee4000bbbb4b4aa48302a6b73461823ea5349bad56d"
  documents = [
    for document in split("\n---", trimspace(data.http.release.response_body)) : yamldecode(document)
    if trimspace(document) != ""
  ]
  manifests = {
    for manifest in local.documents : "${manifest.kind}/${manifest.metadata.name}" => manifest
  }
}

# This public, immutable release asset is fetched by Terraform's HTTP provider.
# It is never executed, rewritten or copied into the public repository corpus.
data "http" "release" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.release_version}/standard-install.yaml"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && sha256(self.response_body) == local.release_sha256
      error_message = "The Gateway API release must match the reviewed checksum."
    }
  }
}

resource "kubernetes_manifest" "standard" {
  for_each = local.manifests
  manifest = each.value

  field_manager {
    name            = "yourown-platform-gateway-api"
    force_conflicts = false
  }

  lifecycle {
    prevent_destroy = true
  }
}
