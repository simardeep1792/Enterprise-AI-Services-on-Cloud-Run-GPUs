# terraform/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Primary deployment region"
  type        = string
  default     = "northamerica-northeast1"
}

# Service account for AI workloads
resource "google_service_account" "ai_service_account" {
  account_id   = "ai-service-account"
  display_name = "AI Services Account"
  description  = "Service account for AI inference workloads"
}

# IAM bindings
resource "google_project_iam_binding" "ai_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.ai_service_account.email}",
  ]
}

resource "google_project_iam_binding" "ai_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"

  members = [
    "serviceAccount:${google_service_account.ai_service_account.email}",
  ]
}

# Cloud Run services
resource "google_cloud_run_service" "document_intelligence" {
  name     = "document-intelligence"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.ai_service_account.email

      containers {
        image = "gcr.io/${var.project_id}/document-intelligence:latest"

        ports {
          container_port = 8080
        }

        resources {
          limits = {
            cpu     = "4"
            memory  = "8Gi"
            "nvidia.com/gpu" = "1"
          }
        }

        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
      }

      timeout_seconds = 300
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "100"
        "autoscaling.knative.dev/minScale" = "0"
        "run.googleapis.com/gpu-type" = "nvidia-l4"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service" "computer_vision" {
  name     = "computer-vision"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.ai_service_account.email

      containers {
        image = "gcr.io/${var.project_id}/computer-vision:latest"

        ports {
          container_port = 8080
        }

        resources {
          limits = {
            cpu     = "4"
            memory  = "8Gi"
            "nvidia.com/gpu" = "1"
          }
        }

        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
      }

      timeout_seconds = 180
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "50"
        "autoscaling.knative.dev/minScale" = "0"
        "run.googleapis.com/gpu-type" = "nvidia-l4"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# IAM for public access (adjust for production)
resource "google_cloud_run_service_iam_binding" "document_intelligence_public" {
  location = google_cloud_run_service.document_intelligence.location
  service  = google_cloud_run_service.document_intelligence.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

resource "google_cloud_run_service_iam_binding" "computer_vision_public" {
  location = google_cloud_run_service.computer_vision.location
  service  = google_cloud_run_service.computer_vision.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

# Outputs
output "document_intelligence_url" {
  value = google_cloud_run_service.document_intelligence.status[0].url
}

output "computer_vision_url" {
  value = google_cloud_run_service.computer_vision.status[0].url
}
