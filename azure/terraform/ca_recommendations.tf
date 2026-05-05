resource "azurerm_container_app" "recommendations" {
  name                         = "${var.project_name}-recommendations"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

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
    }
    
    min_replicas = 0 # Scale to zero to save costs
    max_replicas = 3
  }

  ingress {
    external_enabled = true
    target_port      = 8090
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
}
