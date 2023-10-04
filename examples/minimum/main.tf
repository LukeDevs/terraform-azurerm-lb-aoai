terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.73.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }

  required_version = ">= 1.2.6"
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "load_balanced_open_ai" {
  source           = "../.."
  models_to_deploy = ["gpt-35-turbo-16k", "text-embedding-ada-002"]
  required_application_gateway_settings = {
    region                        = "ukwest",
    virtual_network_address_space = ["10.41.0.0/16"]
  }
}
