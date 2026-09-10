terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

variable "hcp" {
  description = "Exact HCP Stack names supplied through private configuration."
  type = object({
    organization = string
    project      = string
    stack        = string
    deployment   = string
  })
  nullable = false
  validation {
    condition     = alltrue([for value in values(var.hcp) : can(regex("^[A-Za-z0-9_-]+$", value))])
    error_message = "HCP names must be nonempty and contain only letters, digits, underscore or hyphen."
  }
  validation {
    condition = length(join(":", [
      "organization", var.hcp.organization, "project", var.hcp.project,
      "stack", var.hcp.stack, "deployment", var.hcp.deployment, "operation", "apply"
    ])) <= 127
    error_message = "The full HCP subject must fit the documented subject length limit."
  }
}

locals {
  subjects = {
    for phase in ["plan", "apply"] : phase => join(":", [
      "organization", var.hcp.organization, "project", var.hcp.project,
      "stack", var.hcp.stack, "deployment", var.hcp.deployment, "operation", phase
    ])
  }
}

output "subjects" {
  description = "Exact phase-specific subjects; keep resolved values in private state."
  value       = local.subjects
}
