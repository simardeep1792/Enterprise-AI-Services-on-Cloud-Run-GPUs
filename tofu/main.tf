# tofu/main.tf
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

resource "google_service_account" "ai_service_account" {
  account_id   = var.service_account_name
  display_name = "AI Services Account"
  description  = "Service account for AI inference workloads"
}

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

# Conditional GPU configuration
locals {
  # Only include GPU config if explicitly enabled
  gpu_resources = var.enable_gpu ? {
    "nvidia.com/gpu" = "1"
  } : {}

  # Combine base resources with optional GPU
  container_resources = merge({
    cpu    = "4"
    memory = var.enable_gpu ? "16Gi" : "8Gi"  # 16Gi required for GPU, 8Gi for CPU
  }, local.gpu_resources)

  # Only include GPU annotation if enabled
  gpu_annotations = var.enable_gpu ? {
    "run.googleapis.com/gpu-type" = var.gpu_type
  } : {}

  # Combine base annotations with optional GPU
  service_annotations = merge({
    "autoscaling.knative.dev/maxScale" = tostring(var.max_instances)
    "autoscaling.knative.dev/minScale" = "0"
  }, local.gpu_annotations)
}

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
          limits = local.container_resources
        }

        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
      }

      timeout_seconds = 300
    }

    metadata {
      annotations = local.service_annotations
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_binding" "document_intelligence_public" {
  count    = var.enable_public_access ? 1 : 0
  location = google_cloud_run_service.document_intelligence.location
  service  = google_cloud_run_service.document_intelligence.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}
