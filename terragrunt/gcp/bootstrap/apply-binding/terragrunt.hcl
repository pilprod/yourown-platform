include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment = include.root.locals.environment
}

terraform {
  source = "github.com/gruntwork-io/terragrunt-scale-catalog.git//modules/gcp/service-account-iam-binding?ref=57e280bf81ab9b34b51414c22953e6a1dca788eb"
}

dependencies {
  paths = ["../apply-account", "../provider"]
}

inputs = {
  service_account_id = "projects/${local.environment.project_id}/serviceAccounts/${local.environment.apply_account_id}@${local.environment.project_id}.iam.gserviceaccount.com"
  member             = "principalSet://iam.googleapis.com/projects/${local.environment.project_number}/locations/global/workloadIdentityPools/${local.environment.pool_id}/attribute.project_id/${local.environment.gitlab_project_id}"
}
