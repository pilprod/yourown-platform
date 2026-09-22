output "email" {
  description = "Initialized GCS service-agent email."
  value       = data.google_storage_project_service_account.this.email_address
}

output "member" {
  description = "Initialized GCS service agent as an IAM member."
  value       = format("serviceAccount:%s", data.google_storage_project_service_account.this.email_address)
}
