required_providers {
  google = {
    source  = "hashicorp/google"
    version = "7.44.0"
  }
  kubernetes = {
    source  = "hashicorp/kubernetes"
    version = "3.2.1"
  }
  helm = {
    source  = "hashicorp/helm"
    version = "3.3.0"
  }
  http = {
    source  = "hashicorp/http"
    version = "3.6.2"
  }
}

provider "google" "target" {
  config {
    project = var.target.project_id
    region  = var.target.region
    external_credentials {
      audience              = var.federation.audience
      service_account_email = var.federation.service_account_email
      identity_token        = var.identity_token
    }
  }
}

provider "kubernetes" "runtime" {
  config {
    host                   = component.cluster_auth.host
    cluster_ca_certificate = component.cluster_auth.cluster_ca_certificate
    token                  = component.cluster_auth.token
  }
}

provider "helm" "runtime" {
  config {
    kubernetes = {
      host                   = component.cluster_auth.host
      cluster_ca_certificate = component.cluster_auth.cluster_ca_certificate
      token                  = component.cluster_auth.token
    }
  }
}

provider "http" "releases" {
  config {}
}
