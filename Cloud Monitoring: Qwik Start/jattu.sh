#!/bin/bash

# GC_2026 Arcade Shell Script - jattu.sh
# Lab: Cloud Monitoring: Qwik Start

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

show_progress "Starting Cloud Monitoring Lab Automation..."

# Get Default Project ID
PROJECT_ID=$(gcloud config get-value project)
export DEVSHELL_PROJECT_ID=$PROJECT_ID

# Ask user input for Email (required for automation)
read -p "Enter your personal EMAIL for alerts: " USER_EMAIL
export USER_EMAIL

# Fetch Default Zone and Region
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Fallback if metadata is not set
if [ -z "$ZONE" ]; then
    read -p "Enter ZONE (e.g., us-west1-a): " ZONE
    REGION=$(echo $ZONE | sed 's/-[a-z]$//')
fi

show_progress "Using Project: $PROJECT_ID"
show_progress "Using Zone: $ZONE"
show_progress "Using Region: $REGION"

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# ------------------------------------------------
# Task 1 & 2: Create VM and Install Apache/Ops Agent
# ------------------------------------------------
show_progress "Creating LAMP VM instance..."

gcloud compute instances create lamp-1-vm \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --metadata=enable-oslogin=false \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --tags=http-server \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --create-disk=auto-delete=yes,boot=yes,device-name=lamp-1-vm,mode=rw,size=10,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
    --metadata=startup-script='#! /bin/bash
apt-get update
apt-get install -y apache2 php
systemctl enable apache2
systemctl start apache2
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
'

# ------------------------------------------------
# Firewall rule
# ------------------------------------------------
show_progress "Creating firewall rule to allow HTTP..."

gcloud compute firewall-rules create allow-http \
    --project=$PROJECT_ID \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

show_progress "Waiting for VM initialization (30 seconds)..."
sleep 30

# ------------------------------------------------
# Task 3: Create Uptime Check (using REST API for reliability)
# ------------------------------------------------
show_progress "Creating Uptime Check via Monitoring API..."

INSTANCE_ID=$(gcloud compute instances list --filter=lamp-1-vm --zones $ZONE --format="value(id)")

curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
  "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/uptimeCheckConfigs" \
  -d "$(cat <<EOF
{
  "displayName": "Lamp Uptime Check",
  "httpCheck": {
    "path": "/",
    "port": 80,
    "requestMethod": "GET"
  },
  "monitoredResource": {
    "labels": {
      "instance_id": "$INSTANCE_ID",
      "project_id": "$PROJECT_ID",
      "zone": "$ZONE"
    },
    "type": "gce_instance"
  }
}
EOF
)"

# ------------------------------------------------
# Task 4: Create Notification Channel and Alert Policy
# ------------------------------------------------
show_progress "Automating Alert Policy and Notification Channel..."

# Create the channel
cat > email-channel.json <<EOF
{
  "type": "email",
  "displayName": "Personal Alert",
  "description": "Alert notification for $USER_EMAIL",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

gcloud beta monitoring channels create --channel-content-from-file="email-channel.json"

# Get the channel name (id)
CHANNEL_ID=$(gcloud beta monitoring channels list --filter='displayName="Personal Alert"' --format='value(name)')

# Create the alert policy attached to the channel
cat > alert-policy.json <<EOF
{
  "displayName": "Inbound Traffic Alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "VM Instance - Network traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/interface/traffic\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "60s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 500
      }
    }
  ],
  "alertStrategy": {
    "notificationPrompts": [
      "OPENED"
    ]
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$CHANNEL_ID"
  ]
}
EOF

gcloud alpha monitoring policies create --policy-from-file="alert-policy.json"

# ------------------------------------------------
# Task 5: Create Dashboard
# ------------------------------------------------
show_progress "Creating monitoring dashboard..."

cat > dashboard.json <<EOF
{
"displayName": "Cloud Monitoring LAMP Qwik Start Dashboard",
"gridLayout": {
"widgets": [
{
"title": "CPU Load",
"xyChart": {
"dataSets": [{
"timeSeriesQuery": {
"unitOverride": "",
"timeSeriesFilter": {
"filter": "metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
"aggregation": {"alignmentPeriod": "60s","perSeriesAligner": "ALIGN_MEAN"}
}
}
}]
}
},
{
"title": "Received Packets",
"xyChart": {
"dataSets": [{
"timeSeriesQuery": {
"timeSeriesFilter": {
"filter": "metric.type=\"compute.googleapis.com/instance/network/received_packets_count\"",
"aggregation": {"alignmentPeriod": "60s","perSeriesAligner": "ALIGN_RATE"}
}
}
}]
}
}
]
}
}
EOF

gcloud monitoring dashboards create --config-from-file=dashboard.json

# ------------------------------------------------
# Restart VM to trigger logs
# ------------------------------------------------
show_progress "Restarting VM to generate traffic and logs..."

gcloud compute instances stop lamp-1-vm --zone=$ZONE
sleep 10
gcloud compute instances start lamp-1-vm --zone=$ZONE

echo ""
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}    Lab Setup Completed Successfully! 🚀       ${NC}"
echo -e "${GREEN}===============================================${NC}"

echo -e "${BLUE}Check your progress in the lab now.${NC}"
echo ""
echo -e "${YELLOW}Join our WhatsApp community for updates: ${NC}https://chat.whatsapp.com/K9d9xZNy2YqBqu6wvGEh2h"
echo -e "${GREEN}Happy Learning with GC_2026!${NC}"
