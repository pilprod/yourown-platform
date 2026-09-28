locals {
  environment   = jsondecode(file(get_env("YOUROWN_GCP_ENVIRONMENT_FILE")))
  state_suffix  = read_terragrunt_config("${get_original_terragrunt_dir()}/state.hcl").locals.state_suffix
  state_address = "${trimsuffix(get_env("GITLAB_STATE_BASE_URL"), "/")}/${local.environment.state_prefix}-${local.state_suffix}"
}

remote_state {
  backend = "http"
  generate = {
    path      = "yourown_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    address        = local.state_address
    lock_address   = "${local.state_address}/lock"
    unlock_address = "${local.state_address}/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

# Backend secrets use TF_HTTP_USERNAME/TF_HTTP_PASSWORD only. Cloud credentials
# use ADC locally or GOOGLE_OAUTH_ACCESS_TOKEN exchanged from a GitLab CI ID token.
generate "google_provider" {
  path      = "yourown_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project = ${jsonencode(local.environment.project_id)}
    }
    provider "google-beta" {
      project = ${jsonencode(local.environment.project_id)}
    }
  EOF
}

generate "provider_requirements" {
  path      = "yourown_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.11, < 2.0"
      required_providers {
        google = { source = "hashicorp/google", version = "~> 7.0" }
        google-beta = { source = "hashicorp/google-beta", version = "~> 7.0" }
      }
    }
  EOF
}
