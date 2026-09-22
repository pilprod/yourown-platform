component "apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "18.3.0"
  inputs = {
    project_id                  = var.target.project_id
    disable_services_on_destroy = false
    disable_dependent_services  = false
    activate_apis = distinct(concat(
      [
        "serviceusage.googleapis.com",
        "compute.googleapis.com",
        "container.googleapis.com",
        "iam.googleapis.com",
        "logging.googleapis.com",
        "monitoring.googleapis.com",
        "artifactregistry.googleapis.com",
      ],
      tolist(var.additional_services),
      length(var.kms_keyrings) > 0 ? ["cloudkms.googleapis.com"] : [],
      length(var.storage_buckets) > 0 ? ["storage.googleapis.com"] : [],
      length(var.sql_instances) > 0 || var.sql_private_service_access != null ? ["sqladmin.googleapis.com", "servicenetworking.googleapis.com"] : [],
      length(var.secret_containers) > 0 || try(var.gke.enable_secret_manager_csi, false) ? ["secretmanager.googleapis.com"] : [],
      length(var.billing_datasets) > 0 ? ["bigquery.googleapis.com"] : [],
      length(var.billing_budgets) > 0 ? ["billingbudgets.googleapis.com"] : [],
      anytrue([for registry in values(var.registries) : registry.enable_vulnerability_scanning]) ? ["containerscanning.googleapis.com", "containeranalysis.googleapis.com"] : [],
    ))
    # Materialize service agents before optional key grants. These entries grant
    # no project IAM roles; private key policy owns encryption permissions.
    activate_api_identities = [for api in concat(
      length(var.sql_instances) > 0 ? ["sqladmin.googleapis.com"] : [],
      length(var.secret_containers) > 0 ? ["secretmanager.googleapis.com"] : [],
      length(var.registries) > 0 ? ["artifactregistry.googleapis.com"] : [],
      var.gke != null ? ["container.googleapis.com"] : [],
    ) : { api = api, roles = [] }]
  }
  providers = {
    google      = provider.google.target
    google-beta = provider.google-beta.target
  }
}

component "network" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.0"
  inputs = {
    project_id                             = var.target.project_id
    network_name                           = var.target.name
    routing_mode                           = "REGIONAL"
    auto_create_subnetworks                = false
    delete_default_internet_gateway_routes = false
    subnets = [{
      subnet_name               = "${var.target.name}-subnet"
      subnet_ip                 = var.target.network.node_cidr
      subnet_region             = var.target.region
      subnet_private_access     = "true"
      subnet_flow_logs          = tostring(var.target.network.enable_flow_logs)
      subnet_flow_logs_interval = "INTERVAL_5_SEC"
      subnet_flow_logs_sampling = "0.5"
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
    }]
    secondary_ranges = {
      "${var.target.name}-subnet" = [
        { range_name = "${var.target.name}-pods", ip_cidr_range = var.target.network.pod_cidr },
        { range_name = "${var.target.name}-services", ip_cidr_range = var.target.network.service_cidr },
      ]
    }
  }
  providers = {
    google      = provider.google.target
    google-beta = provider.google-beta.target
  }
  depends_on = [component.apis]
}

component "nat_address" {
  for_each = var.target.network.enable_nat && var.target.network.nat_static_ip_name != null ? toset(["enabled"]) : toset([])
  source   = "terraform-google-modules/address/google"
  version  = "5.0.0"
  inputs = {
    project_id         = var.target.project_id
    region             = var.target.region
    names              = [var.target.network.nat_static_ip_name]
    addresses          = [""]
    global             = false
    address_type       = "EXTERNAL"
    subnetwork         = ""
    network_tier       = "PREMIUM"
    enable_cloud_dns   = false
    enable_reverse_dns = false
    labels             = var.target.labels
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis]
}

component "nat" {
  for_each = var.target.network.enable_nat ? toset(["enabled"]) : toset([])
  source   = "terraform-google-modules/cloud-nat/google"
  version  = "6.0.0"
  inputs = {
    project_id                         = var.target.project_id
    region                             = var.target.region
    name                               = "${var.target.name}-nat"
    router                             = "${var.target.name}-router"
    network                            = component.network.network_id
    create_router                      = true
    router_asn                         = null
    nat_ips                            = try(component.nat_address["enabled"].self_links, [])
    min_ports_per_vm                   = tostring(var.target.network.nat_min_ports_per_vm)
    log_config_enable                  = var.target.network.nat_log_filter != ""
    log_config_filter                  = var.target.network.nat_log_filter != "" ? var.target.network.nat_log_filter : "ERRORS_ONLY"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    subnetworks = [{
      name                     = component.network.subnets["${var.target.region}/${var.target.name}-subnet"].self_link
      source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
      secondary_ip_range_names = []
    }]
  }
  providers = {
    google = provider.google.target
    random = provider.random.default
  }
}

component "reserved_address" {
  for_each = var.reserved_addresses
  source   = "terraform-google-modules/address/google"
  version  = "5.0.0"
  inputs = {
    project_id         = var.target.project_id
    region             = var.target.region
    names              = [each.value.name]
    addresses          = [""]
    global             = false
    address_type       = "EXTERNAL"
    subnetwork         = ""
    network_tier       = each.value.network_tier
    enable_cloud_dns   = false
    enable_reverse_dns = false
    labels             = merge(var.target.labels, each.value.labels)
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis]
}

component "node_identity" {
  for_each = var.gke == null ? {} : { enabled = var.gke }
  source   = "terraform-google-modules/service-accounts/google"
  version  = "5.0.0"
  inputs = {
    project_id      = var.target.project_id
    names           = [each.value.node_account_id]
    project_roles   = ["${var.target.project_id}=>roles/container.defaultNodeServiceAccount"]
    grant_xpn_roles = false
    generate_keys   = false
  }
  providers  = { google = provider.google.target }
  depends_on = [component.apis]
}

component "registry" {
  for_each = var.registries
  source   = "https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/archive/6f8e3dfeaf4219c1505035c5dab72585a38bf025.tar.gz//cloud-foundation-fabric-6f8e3dfeaf4219c1505035c5dab72585a38bf025/modules/artifact-registry"
  inputs = {
    project_id                    = var.target.project_id
    location                      = coalesce(each.value.location, var.target.region)
    name                          = each.value.name
    format                        = { docker = { standard = { immutable_tags = each.value.immutable_tags } } }
    enable_vulnerability_scanning = each.value.enable_vulnerability_scanning
    encryption_key                = each.value.encryption_key
    cleanup_policy_dry_run        = each.value.cleanup_policy_dry_run
    cleanup_policies              = each.value.cleanup_policies
    labels                        = merge(var.target.labels, each.value.labels)
    iam_bindings_additive = merge(each.value.iam_members,
      var.gke != null && each.value.grant_node_read ? {
        gke_nodes = {
          role   = "roles/artifactregistry.reader"
          member = component.node_identity["enabled"].iam_email
        }
      } : {},
    )
  }
  providers = {
    google      = provider.google.target
    google-beta = provider.google-beta.target
  }
  depends_on = [component.apis, component.node_identity, component.workload_identity]
}

component "cluster" {
  for_each = var.gke == null ? {} : { enabled = var.gke }
  source   = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version  = "45.0.0"
  inputs = {
    project_id                           = var.target.project_id
    name                                 = var.target.name
    regional                             = each.value.regional
    region                               = var.target.region
    zones                                = each.value.zones
    network                              = component.network.network_name
    subnetwork                           = component.network.subnets["${var.target.region}/${var.target.name}-subnet"].name
    ip_range_pods                        = "${var.target.name}-pods"
    ip_range_services                    = "${var.target.name}-services"
    master_ipv4_cidr_block               = each.value.control_plane_cidr
    enable_private_nodes                 = true
    enable_private_endpoint              = true
    deploy_using_private_endpoint        = true
    master_global_access_enabled         = each.value.master_global_access
    gcp_public_cidrs_access_enabled      = false
    gateway_api_channel                  = "CHANNEL_DISABLED"
    datapath_provider                    = "ADVANCED_DATAPATH"
    enable_shielded_nodes                = true
    issue_client_certificate             = false
    release_channel                      = each.value.release_channel
    identity_namespace                   = "${var.target.project_id}.svc.id.goog"
    node_metadata                        = "GKE_METADATA"
    remove_default_node_pool             = true
    initial_node_count                   = 1
    create_service_account               = false
    service_account                      = component.node_identity[each.key].email
    grant_registry_access                = false
    deletion_protection                  = each.value.deletion_protection
    enable_secret_manager_addon          = each.value.enable_secret_manager_csi
    enable_cost_allocation               = each.value.enable_cost_allocation
    logging_enabled_components           = each.value.logging_components
    monitoring_enabled_components        = each.value.monitoring_components
    monitoring_enable_managed_prometheus = each.value.managed_prometheus
    maintenance_start_time               = each.value.maintenance_start_time
    cluster_resource_labels              = var.target.labels
    database_encryption = each.value.secrets_encryption_key == null ? [] : [{
      state    = "ENCRYPTED"
      key_name = each.value.secrets_encryption_key
    }]
    configure_ip_masq    = false
    stub_domains         = {}
    upstream_nameservers = []
    node_pools = [for name, pool in each.value.node_pools : merge({
      name                                       = name
      machine_type                               = pool.machine_type
      disk_size_gb                               = pool.disk_size_gb
      disk_type                                  = pool.disk_type
      spot                                       = pool.spot
      autoscaling                                = pool.autoscaling != null
      auto_repair                                = true
      auto_upgrade                               = true
      image_type                                 = "COS_CONTAINERD"
      enable_secure_boot                         = true
      enable_integrity_monitoring                = true
      max_surge                                  = 1
      max_unavailable                            = 0
      boot_disk_kms_key                          = pool.boot_disk_kms_key == null ? "" : pool.boot_disk_kms_key
      }, pool.autoscaling == null ? { node_count = pool.node_count } : {
      initial_node_count                         = pool.node_count
      min_count                                  = pool.autoscaling.min_count
      max_count                                  = pool.autoscaling.max_count
    })]
    node_pools_labels          = merge({ all = var.target.labels }, { for name, pool in each.value.node_pools : name => pool.labels })
    node_pools_resource_labels = merge({ all = var.target.labels }, { for name, pool in each.value.node_pools : name => pool.resource_labels })
    node_pools_taints          = { for name, pool in each.value.node_pools : name => pool.taints }
    node_pools_oauth_scopes    = { all = ["https://www.googleapis.com/auth/cloud-platform"] }
    node_pools_metadata        = { all = { disable-legacy-endpoints = "true" } }
  }
  providers = {
    google     = provider.google.target
    kubernetes = provider.kubernetes.unused
    random     = provider.random.default
  }
  depends_on = [component.registry, component.node_identity, component.nat]
}
