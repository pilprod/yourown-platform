include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment = include.root.locals.environment
}

terraform {
  source = "github.com/gruntwork-io/terragrunt-scale-catalog.git//modules/gcp/workload-identity-pool?ref=57e280bf81ab9b34b51414c22953e6a1dca788eb"
}

dependencies {
  paths = ["../apis"]
}

inputs = {
  project_id                = local.environment.project_id
  workload_identity_pool_id = local.environment.pool_id
  display_name              = "GitLab Pipelines"
  disabled                  = false
}
