terraform {
  required_version = ">= 1.16.3, < 2.0.0"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "3.6.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
  }
}
