variable "project_id" {
  description = "GCP Project ID where resources will be created"
  type        = string
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID cannot be empty."
  }
}

variable "region" {
  description = "Primary deployment region for Cloud Run services"
  type        = string
  default     = "northamerica-northeast1"
  validation {
    condition = contains([
      "northamerica-northeast1",
      "northamerica-northeast2",
      "us-central1",
      "us-east1",
      "us-west1"
    ], var.region)
    error_message = "Region must be a valid GCP region that supports Cloud Run GPUs."
  }
}

variable "service_account_name" {
  description = "Name for the AI services service account"
  type        = string
  default     = "ai-service-account"
}

variable "max_instances" {
  description = "Maximum number of instances for auto-scaling"
  type        = number
  default     = 100
  validation {
    condition     = var.max_instances > 0 && var.max_instances <= 1000
    error_message = "Max instances must be between 1 and 1000."
  }
}

variable "gpu_type" {
  description = "Type of GPU to use for Cloud Run services"
  type        = string
  default     = "nvidia-l4"
  validation {
    condition = contains([
      "nvidia-l4"
    ], var.gpu_type)
    error_message = "GPU type must be nvidia-l4 (only supported type in Cloud Run)."
  }
}

variable "enable_public_access" {
  description = "Whether to enable public access to the services (disable for production)"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition = contains([
      "dev",
      "staging",
      "prod"
    ], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
