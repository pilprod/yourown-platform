terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    google = { source = "hashicorp/google", version = "= 8.2.0" }
  }
  # Bucket, prefix and operator identity are configured privately at init.
  backend "gcs" {}
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
  type     = string
  nullable = false
}
variable "name_prefix" {
  type     = string
  nullable = false
}
variable "disabled" {
  type    = bool
  default = false
}

provider "google" {
  project = var.project_id
  # Use short-lived operator ADC/impersonation. No service-account JSON key.
}

resource "google_project_service" "bootstrap" {
  for_each = toset([
    "iam.googleapis.com", "iamcredentials.googleapis.com",
    "sts.googleapis.com", "cloudresourcemanager.googleapis.com"
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "stack_identity" {
  source       = "../../modules/gcp/stack-identity"
  project_id   = var.project_id
  hcp          = var.hcp
  hcp_stack_id = var.hcp_stack_id
  name_prefix  = var.name_prefix
  disabled     = var.disabled
  depends_on   = [google_project_service.bootstrap]
}

output "provider_audience" {
  value     = module.stack_identity.provider_audience
  sensitive = true
}
output "service_accounts" {
  value     = module.stack_identity.service_accounts
  sensitive = true
}
