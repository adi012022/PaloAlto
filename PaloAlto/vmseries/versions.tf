terraform {
  required_version = ">= 0.12.29, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 2.64"
    }
    # random = {
    #   source  = "hashicorp/random"
    #   version = "~> 3.0"
    # }
  }
  backend "azurerm" {
    resource_group_name  = "RG-SANDBOX-CB-TFSTATE"
    storage_account_name = "satfs01sndbcb"
    container_name       = "tfstate01-sandbox-cb"
    key                  = "terraform.palo.sandbox.cb.tfstate"
  }
}

provider "azurerm" {
  features {}
}
