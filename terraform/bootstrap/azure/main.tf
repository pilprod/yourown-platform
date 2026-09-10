terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "= 5.5.0" }
  }
  # Supply the private storage account/container/key at init. No storage keys or SAS.
  backend "azurerm" { use_azuread_auth = true }
}

variable "subscription_id" {
  type      = string
  sensitive = true
  nullable  = false
  validation {
    condition     = can(regex("^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$", var.subscription_id))
    error_message = "Supply the expected Azure subscription identifier privately."
  }
}
variable "tenant_id" {
  type      = string
  sensitive = true
  nullable  = false
  validation {
    condition     = can(regex("^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$", var.tenant_id))
    error_message = "Supply the expected Azure tenant identifier privately."
  }
}
variable "hcp" {
  type = object({
    organization = string
    project      = string
    stack        = string
    deployment   = string
  })
  nullable = false
}
variable "resource_group_name" {
  description = "Private name of the bootstrap-owned identity resource group."
  type        = string
  nullable    = false
}
variable "location" {
  type     = string
  nullable = false
}
variable "name_prefix" {
  type     = string
  nullable = false
}
variable "disabled" {
  type     = bool
  default  = false
  nullable = false
}

provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  tenant_id                       = var.tenant_id
  resource_provider_registrations = "none"
  storage_use_azuread              = true
  # Bootstrap uses an approved short-lived operator session, not the new identities.
  # Normal HCP runtime authentication is separate and must use phase-scoped OIDC.
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "identity" {
  name     = var.resource_group_name
  location = var.location
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = lower(data.azurerm_client_config.current.subscription_id) == lower(var.subscription_id) && lower(data.azurerm_client_config.current.tenant_id) == lower(var.tenant_id)
      error_message = "The authenticated Azure tenant/subscription does not match the private target."
    }
  }
}

module "stack_identity" {
  source              = "../../modules/azure/stack-identity"
  hcp                 = var.hcp
  name_prefix         = var.name_prefix
  resource_group_name = azurerm_resource_group.identity.name
  location            = var.location
  disabled            = var.disabled
}

output "client_ids" {
  value     = module.stack_identity.client_ids
  sensitive = true
}
output "principal_ids" {
  value     = module.stack_identity.principal_ids
  sensitive = true
}
output "identity_ids" {
  value     = module.stack_identity.identity_ids
  sensitive = true
}
