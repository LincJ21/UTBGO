resource "azurerm_container_registry" "acr" {
  name                = "${var.project_name}registry${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true # Required to easily pull images from Container Apps initially
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}
