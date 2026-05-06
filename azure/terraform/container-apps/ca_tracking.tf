resource "azurerm_container_app" "tracking" {
  name                         = "${var.project_name}-tracking"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  template {
    container {
      name   = "tracking"
      image  = var.tracking_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "REDIS_URL"
        secret_name = "redis-url"
      }
      env {
        name        = "DATABASE_URL"
        secret_name = "db-connection-string"
      }
      env {
        name        = "API_KEY"
        secret_name = "tracking-api-key"
      }
    }
    
    min_replicas = 0 # Scale to zero when no traffic
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  secret {
    name  = "redis-url"
    value = var.redis_url
  }
  secret {
    name  = "db-connection-string"
    value = var.db_connection_string
  }
  secret {
    name  = "tracking-api-key"
    value = var.tracking_api_key
  }
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }
}
