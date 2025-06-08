#!/bin/bash
# scripts/cleanup.sh

PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-northamerica-northeast1}"

set -e

# Validate required environment variables
if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: Please set GCP_PROJECT_ID environment variable"
    exit 1
fi

echo "Starting cleanup for project: $PROJECT_ID"
echo "This will delete all resources created by this proof of concept."
echo "Region: $REGION"
echo ""

# Confirm deletion
read -p "Are you sure you want to delete all resources? (yes/no): " confirmation
if [[ "$confirmation" != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Destroying infrastructure using OpenTofu..."

# Set active project
gcloud config set project "$PROJECT_ID"

# Destroy infrastructure using OpenTofu
cd tofu

# Initialize if necessary
if [[ ! -d ".terraform" && ! -d ".tofu" ]]; then
    echo "Initializing OpenTofu..."
    tofu init
fi

# Destroy resources
echo "Running 'tofu destroy'..."
tofu destroy -var="project_id=$PROJECT_ID" -var="region=$REGION" -auto-approve

cd ..

echo ""
echo "Performing additional cleanup steps..."

# Remove container images related to this POC
echo "Cleaning up container images..."
gcloud container images list --repository="gcr.io/$PROJECT_ID" --format="value(name)" | while read image; do
    if [[ "$image" == *"document-intelligence"* ]] || [[ "$image" == *"computer-vision"* ]]; then
        echo "Deleting image: $image"
        gcloud container images delete "$image" --quiet --force-delete-tags || true
    fi
done

# Clean up Cloud Build artifacts
echo "Checking for Cloud Build artifacts..."
gcloud builds list --filter="source.repoSource.repoName:enterprise-ai-*" --format="value(id)" --limit=50 | while read build_id; do
    if [[ -n "$build_id" ]]; then
        echo "Cleaning build artifacts for: $build_id"
        # Note: This does not delete build history, only artifacts if any exist
    fi
done

# Delete remaining Cloud Run services
echo "Looking for remaining Cloud Run services..."
remaining_services=$(gcloud run services list --region="$REGION" --filter="metadata.name:document-intelligence OR metadata.name:computer-vision" --format="value(metadata.name)" 2>/dev/null || echo "")

if [[ -n "$remaining_services" ]]; then
    echo "Deleting remaining Cloud Run services..."
    echo "$remaining_services" | while read service; do
        if [[ -n "$service" ]]; then
            echo "Deleting service: $service"
            gcloud run services delete "$service" --region="$REGION" --quiet || true
        fi
    done
fi

# Remove service account
echo "Checking for service account: ai-service-account@$PROJECT_ID.iam.gserviceaccount.com"
remaining_sa=$(gcloud iam service-accounts list --filter="email:ai-service-account@$PROJECT_ID.iam.gserviceaccount.com" --format="value(email)" 2>/dev/null || echo "")

if [[ -n "$remaining_sa" ]]; then
    echo "Deleting service account: $remaining_sa"
    gcloud iam service-accounts delete "$remaining_sa" --quiet || true
fi

echo ""
echo "Cleanup completed."
echo ""
echo "Summary:"
echo " - All OpenTofu-managed resources destroyed"
echo " - Container images removed from gcr.io/$PROJECT_ID"
echo " - Cloud Build artifacts checked and cleaned"
echo " - Cloud Run services deleted"
echo " - AI-related service accounts removed"
echo ""
echo "Note: Cloud Build history and some logs may still be retained by GCP policies."
echo "If a complete wipe is needed, consider deleting the project directly."
