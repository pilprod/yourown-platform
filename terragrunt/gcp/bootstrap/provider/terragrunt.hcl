include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment = include.root.locals.environment
}

terraform {
  source = "github.com/gruntwork-io/terragrunt-scale-catalog.git//modules/gcp/workload-identity-pool-provider?ref=57e280bf81ab9b34b51414c22953e6a1dca788eb"
}

dependencies {
  paths = ["../pool"]
}

inputs = {
  project_id                         = local.environment.project_id
  workload_identity_pool_id          = local.environment.pool_id
  workload_identity_pool_provider_id = local.environment.provider_id
  display_name                       = "GitLab OIDC"
  issuer_uri                         = "https://gitlab.com"
  allowed_audiences                  = [local.environment.oidc_audience]
  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.project_id"   = "assertion.project_id"
    "attribute.namespace_id" = "assertion.namespace_id"
  }
  # First connection is confined to the selected protected deploy branch.
  # Expanding this to MR plans requires a separate untrusted-code review.
  attribute_condition = "assertion.project_id == '${local.environment.gitlab_project_id}' && assertion.namespace_id == '${local.environment.gitlab_namespace_id}' && assertion.ref_type == 'branch' && assertion.ref == '${local.environment.deploy_branch}' && assertion.ref_protected == 'true'"
  disabled            = false
}
