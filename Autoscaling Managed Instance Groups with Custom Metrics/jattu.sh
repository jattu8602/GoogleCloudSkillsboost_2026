#!/bin/bash

# GC_2026 Arcade Shell Script - jattu.sh
# Lab: Autoscaling Managed Instance Groups with Custom Metrics

set -e # Exit on error
set -o pipefail # Fail on intermediate pipe errors

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}    GOOGLE CLOUD ARCADE 2026 - GC_2026        ${NC}"
echo -e "${BLUE}===============================================${NC}"

# Function to display progress
function show_progress() {
    echo -e "${YELLOW}[PROGRESS]${NC} $1"
}

# Ask user input
echo -e "${YELLOW}Please enter the required configuration:${NC}"
read -p "Enter REGION (example: us-central1): " REGION
read -p "Enter ZONE (example: us-central1-a): " ZONE

echo ""
show_progress "Using Region: $REGION"
show_progress "Using Zone: $ZONE"

# Get Project ID
PROJECT_ID=$(gcloud config get-value project)
show_progress "Project ID: $PROJECT_ID"

# Bucket name
BUCKET_NAME=${PROJECT_ID}-bucket

show_progress "Creating Bucket: $BUCKET_NAME"
gsutil mb -l $REGION gs://$BUCKET_NAME

show_progress "Copying lab files..."
gsutil cp -r gs://spls/gsp087/* gs://$BUCKET_NAME

echo ""
show_progress "Creating Instance Template..."
gcloud compute instance-templates create autoscaling-instance01 \
--machine-type=e2-medium \
--image-family=debian-11 \
--image-project=debian-cloud \
--metadata=startup-script-url=gs://$BUCKET_NAME/startup.sh,gcs-bucket=gs://$BUCKET_NAME

echo ""
show_progress "Creating Managed Instance Group..."
gcloud compute instance-groups managed create autoscaling-instance-group-1 \
--base-instance-name autoscaling-instance \
--size=1 \
--template=autoscaling-instance01 \
--zone=$ZONE

echo ""
show_progress "Waiting for instance to initialize (20 seconds)..."
sleep 20

echo ""
show_progress "Configuring Autoscaling..."
gcloud compute instance-groups managed set-autoscaling autoscaling-instance-group-1 \
--zone=$ZONE \
--min-num-replicas=1 \
--max-num-replicas=3 \
--custom-metric-utilization=metric=custom.googleapis.com/appdemo_queue_depth_01,utilization-target=150,utilization-target-type=GAUGE

echo ""
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}    Lab Setup Completed Successfully! 🚀       ${NC}"
echo -e "${GREEN}===============================================${NC}"

echo -e "${BLUE}Check instances with:${NC}"
echo "gcloud compute instance-groups managed list-instances autoscaling-instance-group-1 --zone=$ZONE"

echo ""
echo -e "${YELLOW}Join our WhatsApp community for updates: ${NC}https://chat.whatsapp.com/K9d9xZNy2YqBqu6wvGEh2h"
echo -e "${GREEN}Happy Learning with GC_2026!${NC}"
