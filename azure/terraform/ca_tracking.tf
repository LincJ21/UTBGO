resource "azurerm_container_app" "tracking" {
  name                         = "${var.project_name}-tracking"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

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
    }
    
    min_replicas = 0 # Scale to zero when no traffic
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 8091
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  secret {
    name  = "redis-url"
    value = var.redis_url
  }
}
