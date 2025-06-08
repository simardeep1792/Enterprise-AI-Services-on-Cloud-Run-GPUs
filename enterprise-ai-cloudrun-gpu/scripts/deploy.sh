#!/bin/bash

PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-northamerica-northeast1}"

set -e

# Validate required environment variables
if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: Please set GCP_PROJECT_ID environment variable"
    exit 1
fi

echo "Starting deployment to project: $PROJECT_ID"

# Set active project
gcloud config set project $PROJECT_ID

# Build and push document intelligence service
echo "Building document intelligence service..."
cd services/document-intelligence
gcloud builds submit --tag gcr.io/$PROJECT_ID/document-intelligence:latest
cd ../..

# Build and push computer vision service
echo "Building computer vision service..."
cd services/computer-vision
gcloud builds submit --tag gcr.io/$PROJECT_ID/computer-vision:latest
cd ../..

# Deploy infrastructure with Terraform
echo "Deploying infrastructure..."
cd terraform
terraform init
terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION"
terraform apply -var="project_id=$PROJECT_ID" -var="region=$REGION" -auto-approve
cd ..

echo "Deployment completed successfully"
echo "Services available at:"
terraform -chdir=terraform output -raw document_intelligence_url
terraform -chdir=terraform output -raw computer_vision_url
