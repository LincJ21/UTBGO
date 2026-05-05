variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "utbgo"
}

variable "location" {
  type        = string
  description = "Azure Region"
  default     = "eastus2"
}

# --- Database & External Services Secrets ---
# These should be passed via GitHub Actions Secrets (TF_VAR_db_connection_string)

variable "db_connection_string" {
  type        = string
  description = "PostgreSQL connection string (Neon)"
  sensitive   = true
}

variable "redis_url" {
  type        = string
  description = "Redis connection URL (Upstash)"
  sensitive   = true
}

variable "jwt_secret" {
  type        = string
  description = "JWT Secret for Authentication"
  sensitive   = true
}

variable "cloudinary_url" {
  type        = string
  description = "Cloudinary connection string"
  sensitive   = true
}

# --- Container Images ---
variable "api_image" {
  type        = string
  description = "Docker image for the Go API"
}

variable "tracking_image" {
  type        = string
  description = "Docker image for the Tracking Service"
}

variable "recommendations_image" {
  type        = string
  description = "Docker image for the Recommendations Service"
}

variable "video_worker_image" {
  type        = string
  description = "Docker image for the Video FFmpeg Worker"
}
