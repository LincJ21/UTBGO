variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "eastus2"
}

variable "project_name" {
  description = "Nombre base para los recursos"
  type        = string
  default     = "utbgo"
}

# --- Credenciales y Secrets (deben pasarse vía terraform.tfvars o CLI) ---

variable "db_connection_string" {
  description = "Connection string a la base de datos (Neon PostgreSQL)"
  type        = string
  sensitive   = true
}

variable "cloudinary_url" {
  description = "URL de Cloudinary"
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "URL de conexión a Redis (Upstash)"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "Clave secreta para firmar los JWT"
  type        = string
  sensitive   = true
}

variable "firebase_project_id" {
  description = "Project ID de Firebase"
  type        = string
  default     = ""
}

variable "google_client_id" {
  description = "Client ID de Google OAuth"
  type        = string
  default     = ""
}

variable "tracking_api_key" {
  description = "API Key interna para el microservicio de Tracking"
  type        = string
  sensitive   = true
}

variable "recommendations_api_key" {
  description = "API Key interna para el microservicio de Recomendaciones"
  type        = string
  sensitive   = true
}

variable "video_worker_api_key" {
  description = "API Key interna para el Video Worker"
  type        = string
  sensitive   = true
}

variable "admin_emails" {
  description = "Lista de correos administradores separados por coma"
  type        = string
}
