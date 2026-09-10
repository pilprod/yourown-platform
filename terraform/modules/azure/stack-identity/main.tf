terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 5.5.0, < 6.0.0" }
  }
}

variable "hcp" {
  description = "Private exact HCP names; the shared subject module rejects wildcards."
  type = object({
    organization = string
    project      = string
    stack        = string
    deployment   = string
  })
  nullable = false
}

variable "resource_group_name" {
  description = "Existing identity resource group, owned by the bootstrap root."
  type        = string
  nullable    = false
  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0 && !strcontains(var.resource_group_name, "/")
    error_message = "Provide a nonempty resource group name, not a resource ID."
  }
}

variable "location" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "Use an explicit canonical Azure region name."
  }
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
  description = "Remove federated credentials; issued access tokens require separate incident response."
  type        = bool
  default     = false
  nullable    = false
}

module "trust" {
  source = "../../hcp/stack-subjects"
  hcp    = var.hcp
}

resource "azurerm_user_assigned_identity" "phase" {
  for_each            = toset(["plan", "apply"])
  name                = "${var.name_prefix}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  lifecycle { prevent_destroy = true }
}

# Azure federated credentials match exact issuer, audience and subject.
# There is no GCP-style extra immutable Stack-ID claim condition here.
resource "azurerm_federated_identity_credential" "phase" {
  for_each                  = var.disabled ? toset([]) : toset(["plan", "apply"])
  name                      = "hcp-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.phase[each.key].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://app.terraform.io"
  subject                   = module.trust.subjects[each.key]
}

# Trust does not grant authorization. No role assignments, application secrets,
# vault access or infrastructure permissions are created by this module.
output "client_ids" {
  value     = { for phase, identity in azurerm_user_assigned_identity.phase : phase => identity.client_id }
  sensitive = true
}
output "principal_ids" {
  value     = { for phase, identity in azurerm_user_assigned_identity.phase : phase => identity.principal_id }
  sensitive = true
}
output "identity_ids" {
  value     = { for phase, identity in azurerm_user_assigned_identity.phase : phase => identity.id }
  sensitive = true
}
