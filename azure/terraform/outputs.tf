output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "api_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "tracking_url" {
  value = "https://${azurerm_container_app.tracking.ingress[0].fqdn}"
}

output "recommendations_url" {
  value = "https://${azurerm_container_app.recommendations.ingress[0].fqdn}"
}
