#!/bin/bash

PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "your-project-id" ]]; then
    echo "Error: Please set GCP_PROJECT_ID environment variable"
    exit 1
fi

gcloud iam service-accounts create ai-service-account \
    --display-name="AI Services Account" \
    --description="Service account for AI inference workloads"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:ai-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/monitoring.metricWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:ai-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:ai-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
