include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment = include.root.locals.environment
}

terraform {
  source = "tfr:///terraform-google-modules/project-factory/google//modules/project_services?version=18.3.0"
}

inputs = {
  project_id                  = local.environment.project_id
  enable_apis                 = true
  activate_apis               = ["iam.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com"]
  activate_api_identities     = []
  disable_services_on_destroy = false
  disable_dependent_services  = false
}
