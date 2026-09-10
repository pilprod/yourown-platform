terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 8.2.0, < 9.0.0" }
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

variable "project_id" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "hcp_stack_id" {
  description = "Private immutable Stack ID; checked in addition to name-based subject claims."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.hcp_stack_id))
    error_message = "An explicit immutable HCP Stack ID is required."
  }
}

variable "name_prefix" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,23}$", var.name_prefix))
    error_message = "Use a lowercase prefix between five and twenty-four characters."
  }
}

variable "disabled" {
  description = "Disable federation for incident response without deleting identities."
  type        = bool
  default     = false
  nullable    = false
}

module "trust" {
  source = "../../hcp/stack-subjects"
  hcp    = var.hcp
}

resource "google_iam_workload_identity_pool" "hcp" {
  project                   = var.project_id
  workload_identity_pool_id = var.name_prefix
  disabled                  = var.disabled
  lifecycle { prevent_destroy = true }
}

resource "google_iam_workload_identity_pool_provider" "hcp" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.hcp.workload_identity_pool_id
  workload_identity_pool_provider_id = "hcp"
  disabled                           = var.disabled
  attribute_mapping                  = { "google.subject" = "assertion.sub" }
  attribute_condition = join(" && ", [
    "assertion.terraform_stack_id == ${jsonencode(var.hcp_stack_id)}",
    "assertion.sub in ${jsonencode(values(module.trust.subjects))}"
  ])
  oidc {
    issuer_uri        = "https://app.terraform.io"
    allowed_audiences = ["gcp.workload.identity"]
  }
}

resource "google_service_account" "phase" {
  for_each   = toset(["plan", "apply"])
  project    = var.project_id
  account_id = "${var.name_prefix}-${each.key}"
  lifecycle { prevent_destroy = true }
}

# Additive membership: never replace the whole service-account IAM policy.
# No project roles or secret-reading rights are granted by this module.
resource "google_service_account_iam_member" "federation" {
  for_each           = toset(["plan", "apply"])
  service_account_id = google_service_account.phase[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.hcp.name}/subject/${module.trust.subjects[each.key]}"
  depends_on         = [google_iam_workload_identity_pool_provider.hcp]
}

output "provider_audience" {
  description = "STS provider resource audience, not the identity token aud value."
  value       = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.hcp.name}"
  sensitive   = true
}

output "service_accounts" {
  value     = { for phase, sa in google_service_account.phase : phase => sa.email }
  sensitive = true
}
