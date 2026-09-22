variable "billing_account_id" {
  description = "Private billing account identifier."
  type        = string
}

variable "display_name" {
  description = "Operator-selected budget label."
  type        = string
}

variable "project_numbers" {
  description = "Explicit project scope; an unfiltered billing-account budget is not supported."
  type        = set(string)
  validation {
    condition = length(var.project_numbers) > 0 && alltrue([
      for number in var.project_numbers : can(regex("^[0-9]+$", number))
    ])
    error_message = "Supply at least one numeric project identifier privately."
  }
}

variable "currency_code" {
  description = "Billing currency code."
  type        = string
  validation {
    condition     = can(regex("^[A-Z]{3}$", var.currency_code))
    error_message = "Currency must be a three-letter uppercase code."
  }
}

variable "monthly_units" {
  description = "Positive monthly amount in whole currency units."
  type        = number
  validation {
    condition     = var.monthly_units > 0 && var.monthly_units == floor(var.monthly_units)
    error_message = "The monthly amount must be a positive whole number."
  }
}

variable "actual_thresholds" {
  description = "Current-spend fractions; at least one threshold across both types is required."
  type        = set(number)
  validation {
    condition = length(var.actual_thresholds) + length(var.forecast_thresholds) > 0 && alltrue([
      for threshold in var.actual_thresholds : threshold > 0
    ])
    error_message = "Supply positive thresholds and at least one actual or forecast threshold."
  }
}

variable "forecast_thresholds" {
  description = "Forecast-spend fractions."
  type        = set(number)
  validation {
    condition     = alltrue([for threshold in var.forecast_thresholds : threshold > 0])
    error_message = "Forecast thresholds must be positive."
  }
}
