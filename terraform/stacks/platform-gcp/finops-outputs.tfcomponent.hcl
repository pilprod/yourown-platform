output "billing_dataset_ids" {
  description = "Private destinations; this output does not mean billing export is enabled."
  type        = map(string)
  value       = { for name, dataset in component.billing_dataset : name => dataset.bigquery_dataset.id }
  sensitive   = true
}

output "billing_budget_names" {
  description = "Private budget resource names."
  type        = map(string)
  value       = { for name, budget in component.billing_budget : name => budget.name }
  sensitive   = true
}
