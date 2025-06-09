#!/bin/bash
# scripts/deploy.sh

PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-northamerica-northeast1}"

set -e

if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: Please set GCP_PROJECT_ID environment variable"
    exit 1
fi

echo "Starting deployment to project: $PROJECT_ID"

gcloud config set project $PROJECT_ID
gcloud auth application-default set-quota-project $PROJECT_ID

echo "Checking required APIs..."
required_apis=(
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "containerregistry.googleapis.com"
)

for api in "${required_apis[@]}"; do
    if ! gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo "Enabling $api..."
        gcloud services enable $api
    else
        echo "$api is already enabled"
    fi
done

# Build and push document intelligence service
echo "Building document intelligence service..."
cd services/document-intelligence

# Check if required files exist
if [[ ! -f "Dockerfile" ]]; then
    echo "Error: Dockerfile not found in services/document-intelligence/"
    exit 1
fi

if [[ ! -f "main.py" ]]; then
    echo "Error: main.py not found in services/document-intelligence/"
    exit 1
fi

if [[ ! -f "requirements.txt" ]]; then
    echo "Error: requirements.txt not found in services/document-intelligence/"
    exit 1
fi

gcloud builds submit --tag gcr.io/$PROJECT_ID/document-intelligence:latest --timeout=20m

cd ../..

# Build and push computer vision service
echo "Building computer vision service..."
cd services/computer-vision

# Check if required files exist
if [[ ! -f "Dockerfile" ]]; then
    echo "Error: Dockerfile not found in services/computer-vision/"
    exit 1
fi

if [[ ! -f "main.py" ]]; then
    echo "Error: main.py not found in services/computer-vision/"
    exit 1
fi

if [[ ! -f "requirements.txt" ]]; then
    echo "Error: requirements.txt not found in services/computer-vision/"
    exit 1
fi

gcloud builds submit --tag gcr.io/$PROJECT_ID/computer-vision:latest --timeout=20m

cd ../..

# Deploy infrastructure with OpenTofu
echo "Deploying infrastructure..."
cd tofu

# Check if tofu is installed
if ! command -v tofu &> /dev/null; then
    echo "Error: OpenTofu is not installed. Please install it from https://opentofu.org/"
    exit 1
fi

tofu init
tofu plan -var="project_id=$PROJECT_ID" -var="region=$REGION"
tofu apply -var="project_id=$PROJECT_ID" -var="region=$REGION" -auto-approve

cd ..

echo "Deployment completed successfully"
echo "Services available at:"
tofu -chdir=tofu output -raw document_intelligence_url
tofu -chdir=tofu output -raw computer_vision_url

echo ""
echo "Test the services using:"
echo "curl -X GET \$(tofu -chdir=tofu output -raw document_intelligence_url)/health"
echo "curl -X GET \$(tofu -chdir=tofu output -raw computer_vision_url)/health"
