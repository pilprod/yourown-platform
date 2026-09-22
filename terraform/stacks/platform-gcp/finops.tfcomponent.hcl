component "billing_dataset" {
  for_each = var.billing_datasets
  source   = "terraform-google-modules/bigquery/google"
  version  = "10.2.1"
  inputs = {
    project_id                 = var.target.project_id
    dataset_id                 = each.value.dataset_id
    location                   = each.value.location
    description                = "Cloud Billing export destination"
    delete_contents_on_destroy = false
    deletion_protection        = true
    dataset_labels             = each.value.labels
    # Keep ACLs out of this resource; additive IAM below owns explicit grants.
    access = []
    tables = []
    views  = []
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis, component.billing_dataset_managers]
}

component "billing_dataset_readers" {
  for_each = { for name, dataset in var.billing_datasets : name => dataset if length(dataset.readers) > 0 }
  source   = "terraform-google-modules/iam/google//modules/bigquery_datasets_iam"
  version  = "8.2.0"
  inputs = {
    project           = var.target.project_id
    bigquery_datasets = [each.value.dataset_id]
    mode              = "additive"
    bindings          = { "roles/bigquery.dataViewer" = tolist(each.value.readers) }
  }
  providers  = { google = provider.google.target }
  depends_on = [component.billing_dataset, component.workload_identity]
}

component "billing_dataset_managers" {
  for_each = length(flatten([for dataset in var.billing_datasets : tolist(dataset.managers)])) > 0 ? toset(["configured"]) : toset([])
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  version  = "8.2.0"
  inputs = {
    projects = [var.target.project_id]
    mode     = "additive"
    bindings = {
      "roles/bigquery.user" = distinct(flatten([for dataset in var.billing_datasets : tolist(dataset.managers)]))
    }
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis, component.workload_identity]
}

component "billing_budget" {
  for_each = var.billing_budgets
  source   = "../../modules/gcp/billing-budget"
  inputs = {
    billing_account_id  = each.value.billing_account_id
    display_name        = each.value.display_name
    project_numbers     = each.value.project_numbers
    currency_code       = each.value.currency_code
    monthly_units       = each.value.monthly_units
    actual_thresholds   = each.value.actual_thresholds
    forecast_thresholds = each.value.forecast_thresholds
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis]
}
