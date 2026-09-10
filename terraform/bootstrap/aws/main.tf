terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 6.64.0" }
  }
  # Supply bucket/key/region privately. Credentials belong in the operator chain.
  backend "s3" { use_lockfile = true }
}

variable "hcp" {
  description = "Private HCP organization/project/Stack/deployment names; no wildcard trust."
  type = object({
    organization = string
    project      = string
    stack        = string
    deployment   = string
  })
  nullable = false
}

variable "account_id" {
  type      = string
  sensitive = true
  nullable  = false
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Supply the expected AWS account privately."
  }
}
variable "region" {
  type     = string
  nullable = false
}
variable "name_prefix" {
  type     = string
  nullable = false
}
variable "create_oidc_provider" {
  description = "Explicit account-owner opt-in. Subsequent stacks reuse its ARN."
  type        = bool
  default     = false
  nullable    = false
}
variable "existing_oidc_provider_arn" {
  type      = string
  default   = null
  sensitive = true
  validation {
    condition     = var.create_oidc_provider ? var.existing_oidc_provider_arn == null : var.existing_oidc_provider_arn != null
    error_message = "Choose exactly one: create the account provider or reuse its private ARN."
  }
}
variable "disabled" {
  type    = bool
  default = false
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  # Use short-lived operator credentials, such as an approved AWS SSO session.
}

# One owner per account. This resource is not part of the reusable role module.
resource "aws_iam_openid_connect_provider" "hcp" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://app.terraform.io"
  client_id_list = ["aws.workload.identity"]
  # No stale hardcoded CA thumbprint; provider/IAM retrieves it on initial create.
  lifecycle { prevent_destroy = true }
}

module "stack_identity" {
  source            = "../../modules/aws/stack-identity"
  hcp               = var.hcp
  name_prefix       = var.name_prefix
  disabled          = var.disabled
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.hcp[0].arn : var.existing_oidc_provider_arn
}

output "role_arns" {
  value     = module.stack_identity.role_arns
  sensitive = true
}
output "oidc_provider_arn" {
  value     = var.create_oidc_provider ? aws_iam_openid_connect_provider.hcp[0].arn : var.existing_oidc_provider_arn
  sensitive = true
}
