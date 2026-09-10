terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.64.0, < 7.0.0" }
  }
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

variable "oidc_provider_arn" {
  description = "Existing account-owned HCP OIDC provider; never created per Stack."
  type        = string
  sensitive   = true
  nullable    = false
}

variable "name_prefix" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,39}$", var.name_prefix))
    error_message = "Use a lowercase prefix between five and forty characters."
  }
}

variable "disabled" {
  description = "Deny new role assumptions; existing STS sessions need separate revocation."
  type        = bool
  default     = false
  nullable    = false
}

module "trust" {
  source = "../../hcp/stack-subjects"
  hcp    = var.hcp
}

data "aws_iam_openid_connect_provider" "hcp" {
  arn = var.oidc_provider_arn
}

resource "aws_iam_role" "phase" {
  for_each             = toset(["plan", "apply"])
  name                 = "${var.name_prefix}-${each.key}"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = var.disabled ? "Deny" : "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_provider_arn }
      Condition = { StringEquals = {
        "app.terraform.io:aud" = "aws.workload.identity"
        "app.terraform.io:sub" = module.trust.subjects[each.key]
      } }
    }]
  })
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = trimsuffix(trimprefix(data.aws_iam_openid_connect_provider.hcp.url, "https://"), "/") == "app.terraform.io" && contains(data.aws_iam_openid_connect_provider.hcp.client_id_list, "aws.workload.identity")
      error_message = "The existing provider must trust the exact HCP issuer and expected audience."
    }
  }
}

# These roles deliberately receive no infrastructure or secret permissions.
# Attach reviewed, resource-scoped policies in the owning bootstrap extension.
output "role_arns" {
  value     = { for phase, role in aws_iam_role.phase : phase => role.arn }
  sensitive = true
}
