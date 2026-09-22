variable "target" {
  description = "Private project, regional network allocations and shared labels. NAT and flow logs are optional; names and allocations are never public defaults."
  type = object({
    project_id = string
    region     = string
    name       = string
    labels     = optional(map(string), {})
    network = object({
      node_cidr            = string
      pod_cidr             = string
      service_cidr         = string
      enable_flow_logs     = optional(bool, false)
      enable_nat           = optional(bool, false)
      nat_static_ip_name   = optional(string)
      nat_min_ports_per_vm = optional(number, 64)
      nat_log_filter       = optional(string, "ERRORS_ONLY")
    })
  })
}

variable "gke" {
  description = "Optional private GKE Standard cluster. Explicit zones determine regional pool placement. node_count is per zone: fixed capacity or initial capacity within the selected autoscaling bounds. External KMS keys and service-agent grants must exist before this Stack."
  type = object({
    regional                  = bool
    zones                     = list(string)
    node_account_id           = string
    control_plane_cidr        = string
    maintenance_start_time    = string
    release_channel           = optional(string, "REGULAR")
    deletion_protection       = optional(bool, true)
    master_global_access      = optional(bool, false)
    secrets_encryption_key    = optional(string)
    enable_secret_manager_csi = optional(bool, false)
    enable_cost_allocation    = optional(bool, true)
    logging_components        = optional(list(string), ["SYSTEM_COMPONENTS"])
    monitoring_components     = optional(list(string), ["SYSTEM_COMPONENTS"])
    managed_prometheus        = optional(bool, false)
    node_pools = map(object({
      machine_type      = string
      node_count        = number
      disk_size_gb      = number
      disk_type         = string
      spot              = optional(bool, false)
      boot_disk_kms_key = optional(string)
      autoscaling = optional(object({
        min_count = number
        max_count = number
      }))
      labels          = optional(map(string), {})
      resource_labels = optional(map(string), {})
      taints = optional(list(object({
        key    = string
        value  = string
        effect = string
      })), [])
    }))
  })
  default = null
}

variable "registries" {
  description = "Optional container repositories keyed by logical identity. Scanning and destructive cleanup require explicit selection. External KMS keys and grants must already exist. The gke_nodes IAM key is reserved when granting node reads."
  type = map(object({
    name                          = string
    location                      = optional(string)
    immutable_tags                = optional(bool, true)
    enable_vulnerability_scanning = optional(bool, false)
    encryption_key                = optional(string)
    cleanup_policy_dry_run        = optional(bool, true)
    grant_node_read               = optional(bool, true)
    labels                        = optional(map(string), {})
    cleanup_policies = optional(map(object({
      action = string
      condition = optional(object({
        tag_state             = optional(string)
        tag_prefixes          = optional(list(string))
        older_than            = optional(string)
        newer_than            = optional(string)
        package_name_prefixes = optional(list(string))
        version_name_prefixes = optional(list(string))
      }))
      most_recent_versions = optional(object({
        package_name_prefixes = optional(list(string))
        keep_count            = optional(number)
      }))
    })), {})
    iam_members = optional(map(object({
      role   = string
      member = string
      condition = optional(object({
        expression  = string
        title       = string
        description = optional(string)
      }))
    })), {})
  }))
  default = {}
}

variable "reserved_addresses" {
  description = "Optional regional public address reservations keyed by logical role. Bind consumers privately; this upstream module does not implement prevent_destroy."
  type = map(object({
    name         = string
    network_tier = optional(string, "PREMIUM")
    labels       = optional(map(string), {})
  }))
  default = {}
}

variable "additional_services" {
  description = "Additional project APIs selected by the private deployment. This Stack remains the single API activation owner for its project."
  type        = set(string)
  default     = []
}

variable "federation" {
  description = "Private WIF binding for this target and run phase, established by an independently approved bootstrap."
  type = object({
    audience              = string
    service_account_email = string
  })
}

variable "identity_token" {
  description = "Short-lived HCP identity token; never a committed static credential."
  type        = string
  sensitive   = true
  ephemeral   = true
}
