variable "billing_datasets" {
  description = "Optional export destination datasets. Enabling Cloud Billing export is a separate billing-account operation, not performed by dataset creation."
  type = map(object({
    dataset_id = string
    location   = string
    labels     = optional(map(string), {})
    readers    = optional(set(string), [])
    managers   = optional(set(string), [])
  }))
  default = {}
}

variable "billing_budgets" {
  description = "Optional protected monthly budgets with private billing/project identifiers, currency and amounts. Thresholds notify; they do not cap spend."
  type = map(object({
    billing_account_id  = string
    display_name        = string
    project_numbers     = set(string)
    currency_code       = string
    monthly_units       = number
    actual_thresholds   = set(number)
    forecast_thresholds = set(number)
  }))
  default = {}
}
