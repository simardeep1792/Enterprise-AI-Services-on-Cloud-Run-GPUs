#!/bin/bash

PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
PROJECT_NAME="${GCP_PROJECT_NAME:-your-project-name}"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "your-project-id" ]]; then
    echo "Error: Please set GCP_PROJECT_ID environment variable"
    exit 1
fi

gcloud config set project $PROJECT_ID

gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable secretmanager.googleapis.com

echo "Project configuration completed for $PROJECT_ID"
