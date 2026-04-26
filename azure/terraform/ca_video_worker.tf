resource "azurerm_container_app" "video_worker" {
  name                         = "${var.project_name}-video-worker"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "video-worker"
      image  = var.video_worker_image
      cpu    = 1.0 # FFmpeg requires significant CPU
      memory = "2Gi"

      env {
        name        = "REDIS_URL"
        secret_name = "redis-url"
      }
      env {
        name        = "CLOUDINARY_URL"
        secret_name = "cloudinary-url"
      }
    }
    
    min_replicas = 0 # Scale to 0 when no videos are being uploaded
    max_replicas = 5 # Allow horizontal scaling for mass uploads
  }

  secret {
    name  = "redis-url"
    value = var.redis_url
  }
  secret {
    name  = "cloudinary-url"
    value = var.cloudinary_url
  }
}
