variable "kms_keyrings" {
  description = "Optional managed key rings. Names, placement, rotation and grant principals come from the private target; service agents must exist before their grants. Preserve key_names order after first deployment."
  type = map(object({
    name                        = string
    location                    = string
    key_names                   = list(string)
    protection_level            = string
    rotation_period             = string
    encrypter_decrypter_members = set(string)
    labels                      = optional(map(string), {})
  }))
  default = {}
}

variable "storage_buckets" {
  description = "Optional shared buckets. Select one managed encryption key or one external key; the Stack initializes the GCS service agent before key grants and encrypted buckets; external key grants remain with their owner. S3 adapter credentials belong to products."
  type = map(object({
    name                    = string
    location                = string
    storage_class           = string
    versioning              = optional(bool, true)
    force_destroy           = optional(bool, false)
    labels                  = optional(map(string), {})
    encryption              = optional(object({ keyring = string, key = string }))
    external_encryption_key = optional(string)
    iam_bindings            = optional(map(list(string)), {})
    lifecycle_rules = optional(set(object({
      action = object({
        type          = string
        storage_class = optional(string)
      })
      condition = object({
        age                        = optional(number)
        num_newer_versions         = optional(number)
        days_since_noncurrent_time = optional(number)
        with_state                 = optional(string)
      })
    })), [])
  }))
  default = {}
}

variable "sql_private_service_access" {
  description = "Explicit allocation for this network's single Private Service Access owner. Required when sql_instances is non-empty; null creates no peering."
  type = object({
    address       = string
    prefix_length = number
  })
  default = null
}

variable "sql_instances" {
  description = "Optional private PostgreSQL instances with IAM users and explicit sizing. No password users, generated credentials, application SQL or adoption operations. Set sql_private_service_access when enabling instances."
  type = map(object({
    name                           = string
    region                         = string
    zone                           = optional(string)
    database_version               = string
    edition                        = string
    availability_type              = string
    tier                           = string
    disk_size                      = number
    disk_type                      = string
    disk_autoresize                = optional(bool, true)
    backup_start_time              = string
    backup_retained_count          = number
    transaction_log_retention_days = number
    encryption                     = optional(object({ keyring = string, key = string }))
    external_encryption_key        = optional(string)
    labels                         = optional(map(string), {})
    database_flags                 = optional(map(string), {})
    maintenance_window = object({
      day          = number
      hour         = number
      update_track = string
    })
    databases = optional(list(object({
      name      = string
      charset   = optional(string)
      collation = optional(string)
    })), [])
    iam_users = optional(list(object({
      id    = string
      email = string
      type  = optional(string)
    })), [])
  }))
  default = {}
}

variable "secret_containers" {
  description = "Optional Secret Manager containers and additive access grants. Each replica location is explicit; versions and secret payloads are owned by the approved secret publisher. Select at most one encryption source."
  type = map(object({
    name                    = string
    replica_locations       = set(string)
    encryption              = optional(object({ keyring = string, key = string }))
    external_encryption_key = optional(string)
    accessors               = optional(set(string), [])
    labels                  = optional(map(string), {})
  }))
  default = {}
}
