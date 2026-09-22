output "kms_keys" {
  description = "Managed key resource identifiers by logical ring and key name. No key material is exported."
  type        = map(map(string))
  value       = { for key, ring in component.kms : key => ring.keys }
  sensitive   = true
}

output "storage_buckets" {
  description = "Shared bucket names by logical capability key."
  type        = map(string)
  value       = { for key, bucket in component.storage : key => bucket.name }
  sensitive   = true
}

output "sql_instances" {
  description = "Private PostgreSQL connection references; no passwords or generated connection URI."
  type = map(object({
    name            = string
    connection_name = string
    private_address = string
  }))
  value = {
    for key, instance in component.postgresql : key => {
      name            = instance.instance_name
      connection_name = instance.instance_connection_name
      private_address = instance.private_ip_address
    }
  }
  sensitive = true
}

output "secret_containers" {
  description = "Secret resource identifiers by logical capability key; versions are managed outside this Stack."
  type        = map(string)
  value       = { for key, secret in component.secrets : key => secret.secret_names[0] }
  sensitive   = true
}
