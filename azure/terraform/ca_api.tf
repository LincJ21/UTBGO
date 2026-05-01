resource "azurerm_container_app" "api" {
  name                         = "${var.project_name}-api"
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
      name   = "api"
      image  = var.api_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "GIN_MODE"
        value = "release"
      }
      env {
        name  = "ALLOWED_ORIGINS"
        value = "https://utbgo-api.mangoglacier-215c4d32.eastus2.azurecontainerapps.io,https://utbgo.com"
      }
      env {
        name        = "DB_CONNECTION_STRING"
        secret_name = "db-connection-string"
      }
      env {
        name        = "REDIS_URL"
        secret_name = "redis-url"
      }
      env {
        name        = "JWT_SECRET_KEY"
        secret_name = "jwt-secret"
      }
      env {
        name        = "CLOUDINARY_URL"
        secret_name = "cloudinary-url"
      }
      env {
        name  = "STORAGE_PROVIDER"
        value = var.storage_provider
      }
      env {
        name  = "GOOGLE_CLIENT_ID"
        value = var.google_client_id
      }
      env {
        name  = "FIREBASE_PROJECT_ID"
        value = var.firebase_project_id
      }
      env {
        name  = "INSTITUTIONAL_DOMAIN"
        value = var.institutional_domain
      }
      env {
        name  = "ADMIN_DOMAIN"
        value = var.admin_domain
      }
      env {
        name  = "ADMIN_EMAILS"
        value = var.admin_emails
      }
      env {
        name  = "RECOMMENDATIONS_SERVICE_URL"
        value = "http://${var.project_name}-recommendations"
      }
      env {
        name  = "TRACKING_SERVICE_URL"
        value = "http://${var.project_name}-tracking"
      }
      env {
        name        = "RECOMMENDATIONS_API_KEY"
        secret_name = "recommendations-api-key"
      }
      env {
        name        = "TRACKING_API_KEY"
        secret_name = "tracking-api-key"
      }
    }
    
    min_replicas = 1
    max_replicas = 10
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
    name  = "jwt-secret"
    value = var.jwt_secret
  }
  secret {
    name  = "cloudinary-url"
    value = var.cloudinary_url
  }
  secret {
    name  = "recommendations-api-key"
    value = var.recommendations_api_key
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
