resource "azurerm_container_app" "recommendations" {
  name                         = "${var.project_name}-recommendations"
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
      name   = "recommendations"
      image  = var.recommendations_image
      cpu    = 1.0 # ML Service needs more CPU
      memory = "2Gi" # LightGBM in memory requires at least 2Gi

      env {
        name        = "DB_CONNECTION_STRING"
        secret_name = "db-connection-string"
      }
      env {
        name        = "REDIS_URL"
        secret_name = "redis-url"
      }
      env {
        name        = "API_KEY"
        secret_name = "recommendations-api-key"
      }
    }
    
    min_replicas = 0 # Scale to zero to save costs
    max_replicas = 3
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
    name  = "db-connection-string"
    value = var.db_connection_string
  }
  secret {
    name  = "redis-url"
    value = var.redis_url
  }
  secret {
    name  = "recommendations-api-key"
    value = var.recommendations_api_key
  }
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }
}
