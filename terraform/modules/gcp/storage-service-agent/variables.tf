variable "project_id" {
  description = "Private target project whose GCS service agent must be available."
  type        = string
  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "A target project is required."
  }
}
