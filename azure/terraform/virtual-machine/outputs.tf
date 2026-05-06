output "api_url" {
  description = "URL para acceder a la API de UTBGO"
  value       = "http://${azurerm_public_ip.public_ip.ip_address}:8080"
}

output "ssh_command" {
  description = "Comando para conectarse a la máquina virtual"
  value       = "ssh -i utbgo_key.pem adminuser@${azurerm_public_ip.public_ip.ip_address}"
}
