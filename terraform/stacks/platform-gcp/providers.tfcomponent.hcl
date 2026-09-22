required_providers {
  google = {
    source  = "hashicorp/google"
    version = "7.44.0"
  }
  google-beta = {
    source  = "hashicorp/google-beta"
    version = "7.44.0"
  }
  random = {
    source  = "hashicorp/random"
    version = "3.9.1"
  }
  null = {
    source  = "hashicorp/null"
    version = "3.3.2"
  }
  kubernetes = {
    source  = "hashicorp/kubernetes"
    version = "3.2.1"
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

provider "google-beta" "target" {
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

provider "random" "default" {
  config {}
}

provider "null" "default" {
  config {}
}

# The private-cluster module requires this provider even with all Kubernetes
# resources disabled. Runtime resources belong to a separately authenticated Stack.
provider "kubernetes" "unused" {
  config {}
}
