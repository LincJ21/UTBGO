terraform {
  backend "azurerm" {
    resource_group_name  = "utbgo-tfstate-rg"
    storage_account_name = "utbgotfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
