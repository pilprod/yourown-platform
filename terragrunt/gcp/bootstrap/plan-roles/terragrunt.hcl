include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment = include.root.locals.environment
}

terraform {
  source = "github.com/gruntwork-io/terragrunt-scale-catalog.git//modules/gcp/project-iam-member?ref=57e280bf81ab9b34b51414c22953e6a1dca788eb"
}

dependencies {
  paths = ["../plan-account"]
}

inputs = {
  project_id = local.environment.project_id
  member     = "serviceAccount:${local.environment.plan_account_id}@${local.environment.project_id}.iam.gserviceaccount.com"
  roles      = ["roles/viewer"]
}
