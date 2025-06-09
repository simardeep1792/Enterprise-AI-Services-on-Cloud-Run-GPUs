# tofu/variables.tf
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
}

variable "service_account_name" {
  description = "Name for the AI services service account"
  type        = string
  default     = "ai-service-account"
}

variable "max_instances" {
  description = "Maximum number of instances for auto-scaling"
  type        = number
  default     = 10
}

variable "gpu_type" {
  description = "Type of GPU to use for Cloud Run services"
  type        = string
  default     = "nvidia-t4"
  validation {
    condition = contains([
      "nvidia-t4",
      "nvidia-l4"
    ], var.gpu_type)
    error_message = "GPU type must be nvidia-t4 or nvidia-l4."
  }
}

variable "enable_public_access" {
  description = "Whether to enable public access to the services"
  type        = bool
  default     = true
}

# New variable to control GPU usage
variable "enable_gpu" {
  description = "Enable GPU acceleration (requires GPU quota)"
  type        = bool
  default     = false  # Start with CPU-only by default
}
