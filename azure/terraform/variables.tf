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

# --- Internal Service Keys ---

variable "recommendations_api_key" {
  type        = string
  description = "API Key for Recommendations Service"
  sensitive   = true
}

variable "tracking_api_key" {
  type        = string
  description = "API Key for Tracking Service"
  sensitive   = true
}

# --- OIDC / Identity Broker ---

variable "google_client_id" {
  type        = string
  description = "Google Client ID for OIDC"
}

variable "firebase_project_id" {
  type        = string
  description = "Firebase Project ID for token validation"
}

# --- Domains & Roles ---

variable "institutional_domain" {
  type        = string
  description = "Domain for institutional accounts (e.g. utb.edu.co)"
  default     = "utb.edu.co"
}

variable "admin_domain" {
  type        = string
  description = "Domain for admin accounts"
  default     = "admin.utb.edu.co"
}

variable "admin_emails" {
  type        = string
  description = "Comma-separated list of admin emails for testing"
  default     = ""
}

# --- Storage ---

variable "storage_provider" {
  type        = string
  description = "Primary storage provider (azure or cloudinary)"
  default     = "cloudinary"
}
