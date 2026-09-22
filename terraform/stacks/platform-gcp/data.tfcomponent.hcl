# Optional shared data capabilities are pinned upstream modules. Encrypted
# consumers wait for key-level IAM; external keys retain their external owner.
locals {
  storage_encryption_keys = {
    for key, bucket in var.storage_buckets : key => one(concat(
      bucket.encryption == null ? [] : [component.kms[bucket.encryption.keyring].keys[bucket.encryption.key]],
      bucket.external_encryption_key == null ? [] : [bucket.external_encryption_key],
    ))
  }
  sql_encryption_keys = {
    for key, instance in var.sql_instances : key => one(concat(
      instance.encryption == null ? [] : [component.kms[instance.encryption.keyring].keys[instance.encryption.key]],
      instance.external_encryption_key == null ? [] : [instance.external_encryption_key],
    ))
  }
  secret_encryption_keys = {
    for key, secret in var.secret_containers : key => one(concat(
      secret.encryption == null ? [] : [component.kms[secret.encryption.keyring].keys[secret.encryption.key]],
      secret.external_encryption_key == null ? [] : [secret.external_encryption_key],
    ))
  }
}

component "storage_service_agent" {
  for_each = anytrue([
    for bucket in values(var.storage_buckets) :
    bucket.encryption != null || bucket.external_encryption_key != null
  ]) ? toset(["enabled"]) : toset([])
  source     = "../../modules/gcp/storage-service-agent"
  inputs     = { project_id = var.target.project_id }
  providers  = { google = provider.google.target }
  depends_on = [component.apis]
}

component "kms" {
  for_each = var.kms_keyrings
  source   = "terraform-google-modules/kms/google"
  version  = "4.1.2"
  inputs = {
    project_id           = var.target.project_id
    location             = each.value.location
    keyring              = each.value.name
    keys                 = each.value.key_names
    key_protection_level = each.value.protection_level
    key_rotation_period  = each.value.rotation_period
    key_algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    purpose              = "ENCRYPT_DECRYPT"
    prevent_destroy      = true
    labels               = each.value.labels
    set_owners_for       = []
    set_encrypters_for   = []
    set_decrypters_for   = []
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis]
}

component "kms_key_access" {
  for_each = var.kms_keyrings
  source   = "terraform-google-modules/iam/google//modules/kms_crypto_keys_iam"
  version  = "8.2.0"
  inputs = {
    # The IAM helper uses entity/member values as keys. These identifiers are
    # determined by private inputs; the dependency waits for actual creation.
    kms_crypto_keys = [
      for name in each.value.key_names :
      "projects/${var.target.project_id}/locations/${each.value.location}/keyRings/${each.value.name}/cryptoKeys/${name}"
    ]
    mode = "additive"
    bindings = {
      "roles/cloudkms.cryptoKeyEncrypterDecrypter" = tolist(each.value.encrypter_decrypter_members)
    }
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis, component.storage_service_agent, component.kms, component.workload_identity]
}

component "storage" {
  for_each = var.storage_buckets
  source   = "terraform-google-modules/cloud-storage/google"
  version  = "12.3.0"
  inputs = {
    project_id               = var.target.project_id
    names                    = [each.value.name]
    prefix                   = ""
    randomize_suffix         = false
    location                 = each.value.location
    storage_class            = each.value.storage_class
    bucket_policy_only       = { (lower(each.value.name)) = true }
    public_access_prevention = "enforced"
    versioning               = { (lower(each.value.name)) = each.value.versioning }
    force_destroy            = { (lower(each.value.name)) = each.value.force_destroy }
    encryption_key_names     = local.storage_encryption_keys[each.key] == null ? {} : { (lower(each.value.name)) = local.storage_encryption_keys[each.key] }
    lifecycle_rules          = each.value.lifecycle_rules
    labels                   = each.value.labels
    set_admin_roles          = false
    set_creator_roles        = false
    set_viewer_roles         = false
    set_hmac_key_admin_roles = false
    set_storage_admin_roles  = false
    set_hmac_access          = false
  }
  providers = {
    google = provider.google.target
    random = provider.random.default
  }
  depends_on = [component.apis, component.storage_service_agent, component.kms_key_access]
}

component "storage_access" {
  for_each = var.storage_buckets
  source   = "terraform-google-modules/iam/google//modules/storage_buckets_iam"
  version  = "8.2.0"
  inputs = {
    storage_buckets = [each.value.name]
    mode            = "additive"
    bindings        = each.value.iam_bindings
  }
  providers  = { google = provider.google.target }
  depends_on = [component.storage, component.workload_identity]
}

component "private_service_access" {
  for_each = var.sql_private_service_access == null ? {} : { enabled = var.sql_private_service_access }
  source   = "terraform-google-modules/sql-db/google//modules/private_service_access"
  version  = "28.3.0"
  inputs = {
    project_id      = var.target.project_id
    vpc_network     = component.network.network_name
    address         = each.value.address
    prefix_length   = each.value.prefix_length
    ip_version      = "IPV4"
    deletion_policy = null
  }
  providers = {
    google      = provider.google.target
    google-beta = provider.google-beta.target
    null        = provider.null.default
  }
  depends_on = [component.apis, component.network]
}

component "postgresql" {
  for_each = var.sql_instances
  source   = "terraform-google-modules/sql-db/google//modules/postgresql"
  version  = "28.3.0"
  inputs = {
    project_id                      = var.target.project_id
    name                            = each.value.name
    region                          = each.value.region
    zone                            = each.value.zone
    database_version                = each.value.database_version
    edition                         = each.value.edition
    availability_type               = each.value.availability_type
    tier                            = each.value.tier
    disk_size                       = each.value.disk_size
    disk_type                       = each.value.disk_type
    disk_autoresize                 = each.value.disk_autoresize
    deletion_protection             = true
    deletion_protection_enabled     = true
    encryption_key_name             = local.sql_encryption_keys[each.key]
    user_labels                     = each.value.labels
    random_instance_name            = false
    enable_default_db               = false
    enable_default_user             = false
    additional_users                = []
    additional_databases            = each.value.databases
    iam_users                       = each.value.iam_users
    maintenance_window_day          = each.value.maintenance_window.day
    maintenance_window_hour         = each.value.maintenance_window.hour
    maintenance_window_update_track = each.value.maintenance_window.update_track
    database_flags = concat(
      [{ name = "cloudsql.iam_authentication", value = "on" }],
      [for name, value in each.value.database_flags : { name = name, value = value } if name != "cloudsql.iam_authentication"],
    )
    ip_configuration = {
      ipv4_enabled                                  = false
      private_network                               = component.network.network_self_link
      allocated_ip_range                            = component.private_service_access["enabled"].google_compute_global_address_name
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
      authorized_networks                           = []
    }
    backup_configuration = {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = each.value.backup_start_time
      retained_backups               = each.value.backup_retained_count
      retention_unit                 = "COUNT"
      transaction_log_retention_days = tostring(each.value.transaction_log_retention_days)
    }
    create_timeout    = "60m"
    update_timeout    = "60m"
    delete_timeout    = "60m"
    module_depends_on = [component.private_service_access["enabled"].peering_completed]
  }
  providers = {
    google      = provider.google.target
    google-beta = provider.google-beta.target
    random      = provider.random.default
    null        = provider.null.default
  }
  depends_on = [component.private_service_access, component.kms_key_access, component.workload_identity]
}

component "secrets" {
  for_each = var.secret_containers
  source   = "GoogleCloudPlatform/secret-manager/google"
  version  = "0.9.0"
  inputs = {
    project_id = var.target.project_id
    secrets = [{
      name           = each.value.name
      create_version = false
    }]
    user_managed_replication = {
      (each.value.name) = [
        for location in each.value.replica_locations : {
          location     = location
          kms_key_name = local.secret_encryption_keys[each.key]
        }
      ]
    }
    labels                 = { (each.value.name) = each.value.labels }
    secret_accessors_list  = []
    add_kms_permissions    = []
    add_pubsub_permissions = []
  }
  providers = {
    google      = provider.google.target
    google-beta = provider.google-beta.target
  }
  depends_on = [component.apis, component.kms_key_access]
}

component "secret_access" {
  for_each = var.secret_containers
  source   = "terraform-google-modules/iam/google//modules/secret_manager_iam"
  version  = "8.2.0"
  inputs = {
    project = var.target.project_id
    secrets = [each.value.name]
    mode    = "additive"
    bindings = {
      "roles/secretmanager.secretAccessor" = tolist(each.value.accessors)
    }
  }
  providers  = { google = provider.google.target }
  depends_on = [component.secrets, component.workload_identity]
}
