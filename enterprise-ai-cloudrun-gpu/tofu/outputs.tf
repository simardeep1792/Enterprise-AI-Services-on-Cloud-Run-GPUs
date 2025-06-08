output "project_id" {
  description = "The GCP project ID where resources were created"
  value       = var.project_id
}

output "region" {
  description = "The primary region where services are deployed"
  value       = var.region
}

output "service_account_email" {
  description = "Email address of the AI services service account"
  value       = google_service_account.ai_service_account.email
}

output "document_intelligence_url" {
  description = "URL of the document intelligence service"
  value       = google_cloud_run_service.document_intelligence.status[0].url
}

output "document_intelligence_name" {
  description = "Name of the document intelligence service"
  value       = google_cloud_run_service.document_intelligence.name
}

output "computer_vision_url" {
  description = "URL of the computer vision service"
  value       = google_cloud_run_service.computer_vision.status[0].url
}

output "computer_vision_name" {
  description = "Name of the computer vision service"
  value       = google_cloud_run_service.computer_vision.name
}

output "deployment_info" {
  description = "Summary of deployment information"
  value = {
    project_id               = var.project_id
    region                  = var.region
    environment             = var.environment
    gpu_type               = var.gpu_type
    max_instances          = var.max_instances
    document_service_url   = google_cloud_run_service.document_intelligence.status[0].url
    vision_service_url     = google_cloud_run_service.computer_vision.status[0].url
    service_account_email  = google_service_account.ai_service_account.email
  }
}
