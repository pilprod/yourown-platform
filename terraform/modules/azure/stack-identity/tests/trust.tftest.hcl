mock_provider "azurerm" {}

variables {
  resource_group_name = "example-identities"
  location            = "westeurope"
  name_prefix         = "example-hcp"
  hcp                 = { organization = "example", project = "core", stack = "runtime", deployment = "test" }
}

run "phase_scoped_federation" {
  command = plan
  assert {
    condition     = length(azurerm_user_assigned_identity.phase) == 2 && azurerm_user_assigned_identity.phase["plan"].name != azurerm_user_assigned_identity.phase["apply"].name
    error_message = "Plan and apply must have distinct identities."
  }
  assert {
    condition     = alltrue([for phase, credential in azurerm_federated_identity_credential.phase : credential.issuer == "https://app.terraform.io" && toset(credential.audience) == toset(["api://AzureADTokenExchange"])])
    error_message = "Every credential must restrict issuer and audience."
  }
  assert {
    condition     = alltrue([for phase, credential in azurerm_federated_identity_credential.phase : credential.subject == module.trust.subjects[phase] && endswith(credential.subject, ":operation:${phase}") && !strcontains(credential.subject, "*")])
    error_message = "Each identity must trust only its exact deployment and operation."
  }
}

run "disable_new_federation" {
  command = plan
  variables { disabled = true }
  assert {
    condition     = length(azurerm_federated_identity_credential.phase) == 0 && length(azurerm_user_assigned_identity.phase) == 2
    error_message = "Disabling trust must remove credentials without deleting identities."
  }
}

run "reject_invalid_prefix" {
  command = plan
  variables { name_prefix = "*" }
  expect_failures = [var.name_prefix]
}

run "reject_empty_region" {
  command = plan
  variables { location = "" }
  expect_failures = [var.location]
}

run "reject_empty_resource_group" {
  command = plan
  variables { resource_group_name = "" }
  expect_failures = [var.resource_group_name]
}
