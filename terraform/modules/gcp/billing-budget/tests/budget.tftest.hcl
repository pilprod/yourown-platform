mock_provider "google" {}

variables {
  billing_account_id  = "synthetic-billing-account"
  display_name        = "Synthetic budget"
  project_numbers     = [join("", [for i in range(12) : "1"])]
  currency_code       = "USD"
  monthly_units       = 100
  actual_thresholds   = [0.5, 1]
  forecast_thresholds = [1]
}

run "mixed_thresholds_and_project_scope" {
  command = plan
  assert {
    condition = toset([
      for rule in google_billing_budget.monthly.threshold_rules : rule.spend_basis
    ]) == toset(["CURRENT_SPEND", "FORECASTED_SPEND"])
    error_message = "One budget must preserve both actual and forecast notifications."
  }
  assert {
    condition = google_billing_budget.monthly.budget_filter[0].projects == toset([
      for number in var.project_numbers : "projects/${number}"
    ]) && google_billing_budget.monthly.amount[0].specified_amount[0].currency_code == var.currency_code
    error_message = "The budget must use only the selected project scope and currency."
  }
}

run "reject_unfiltered_budget" {
  command = plan
  variables { project_numbers = [] }
  expect_failures = [var.project_numbers]
}

run "reject_empty_notifications" {
  command = plan
  variables {
    actual_thresholds   = []
    forecast_thresholds = []
  }
  expect_failures = [var.actual_thresholds]
}

run "reject_fractional_units" {
  command = plan
  variables { monthly_units = 0.5 }
  expect_failures = [var.monthly_units]
}
