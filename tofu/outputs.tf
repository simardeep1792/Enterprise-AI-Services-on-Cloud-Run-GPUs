output "document_intelligence_url" {
  description = "URL of the document intelligence service"
  value       = google_cloud_run_service.document_intelligence.status[0].url
}

output "service_account_email" {
  description = "Email address of the AI services service account"
  value       = google_service_account.ai_service_account.email
}
