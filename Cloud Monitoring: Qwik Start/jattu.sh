#!/bin/bash

# GC_2026 Arcade Shell Script - jattu.sh
# Lab: Cloud Monitoring: Qwik Start

# Exit on error
set -e

# --- Color Definitions ---
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
BOLD=`tput bold`
RESET=`tput sgr0`

echo -e "${BLUE}${BOLD}=================================================${RESET}"
echo -e "${BLUE}${BOLD}    GOOGLE CLOUD ARCADE 2026 - GC_2026          ${RESET}"
echo -e "${BLUE}${BOLD}=================================================${RESET}"
echo -e "${CYAN}${BOLD}   Cloud Monitoring: Qwik Start - Automation     ${RESET}"
echo -e "${BLUE}${BOLD}=================================================${RESET}"

# Function to display progress
function show_progress() {
    echo -e "${YELLOW}${BOLD}[PROGRESS]${RESET} ${CYAN}$1${RESET}"
}

show_progress "Initializing environment..."

# 1. Set Project ID
export PROJECT_ID=$(gcloud config get-value project)
export DEVSHELL_PROJECT_ID=$PROJECT_ID

# 2. Get User Email for Alerting
echo -e "${MAGENTA}${BOLD}-------------------------------------------------${RESET}"
read -p "Enter your personal EMAIL for alerts: " USER_EMAIL
export USER_EMAIL
echo -e "${MAGENTA}${BOLD}-------------------------------------------------${RESET}"

# 3. Detect Zone and Region
show_progress "Detecting default zone and region..."
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Fallback if metadata is not set
if [ -z "$ZONE" ]; then
    show_progress "Automatic detection failed. Please enter the Zone."
    read -p "Enter ZONE (e.g., us-west1-a): " ZONE
    REGION=$(echo $ZONE | sed 's/-[a-z]$//')
fi

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

echo -e "${GREEN}${BOLD}Project:${RESET} $PROJECT_ID"
echo -e "${GREEN}${BOLD}Zone:   ${RESET} $ZONE"
echo -e "${GREEN}${BOLD}Region: ${RESET} $REGION"

# ------------------------------------------------
# Task 1 & 2: Create VM and Install Software
# ------------------------------------------------
show_progress "Creating LAMP VM instance (Debian 12)..."

# Check if instance already exists
if gcloud compute instances describe lamp-1-vm --zone=$ZONE &>/dev/null; then
    show_progress "VM lamp-1-vm already exists. Skipping creation."
else
    gcloud compute instances create lamp-1-vm \
        --project=$PROJECT_ID \
        --zone=$ZONE \
        --machine-type=e2-medium \
        --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
        --metadata=enable-oslogin=false \
        --tags=http-server \
        --image-family=debian-12 \
        --image-project=debian-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-balanced \
        --metadata=startup-script='#! /bin/bash
apt-get update
apt-get install -y apache2 php
systemctl enable apache2
systemctl start apache2
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
'
fi

# ------------------------------------------------
# Firewall Rule
# ------------------------------------------------
show_progress "Configuring firewall for HTTP traffic..."

gcloud compute firewall-rules create allow-http \
    --project=$PROJECT_ID \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server --quiet || true

show_progress "Waiting for VM services to initialize (30 seconds)..."
sleep 30

# ------------------------------------------------
# Task 3: Create Uptime Check (using REST API)
# ------------------------------------------------
show_progress "Creating Uptime Check (Resource: Port 80)..."

INSTANCE_ID=$(gcloud compute instances list --filter=lamp-1-vm --zones $ZONE --format="value(id)")
EXTERNAL_IP=$(gcloud compute instances describe lamp-1-vm --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

# Create Uptime Check Config via REST to ensure 100% lab compliance with URL types
cat > uptime-check.json <<EOF
{
  "displayName": "Lamp Uptime Check",
  "httpCheck": { "path": "/", "port": 80, "requestMethod": "GET" },
  "monitoredResource": {
    "labels": { "host": "$EXTERNAL_IP", "project_id": "$PROJECT_ID" },
    "type": "uptime_url"
  }
}
EOF

curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
  "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/uptimeCheckConfigs" \
  -d @uptime-check.json

# ------------------------------------------------
# Task 4: Notification Channel and Alert Policy
# ------------------------------------------------
show_progress "Automating Alert Policy and Notification Channels..."

# Create the channel
cat > email-channel.json <<EOF
{
  "type": "email",
  "displayName": "GC_2026 Alert",
  "description": "Lab alert channel",
  "labels": { "email_address": "$USER_EMAIL" }
}
EOF

gcloud beta monitoring channels create --channel-content-from-file="email-channel.json"

# Get the channel name (id)
CHANNEL_ID=$(gcloud beta monitoring channels list --filter='displayName="GC_2026 Alert"' --format='value(name)')

# Create the alert policy attached to the channel
cat > alert-policy.json <<EOF
{
  "displayName": "Inbound Traffic Alert",
  "conditions": [{
      "displayName": "VM Instance - Network traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/interface/traffic\"",
        "aggregations": [{ "alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE" }],
        "comparison": "COMPARISON_GT",
        "duration": "60s",
        "thresholdValue": 500
      }
  }],
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": ["$CHANNEL_ID"]
}
EOF

gcloud alpha monitoring policies create --policy-from-file="alert-policy.json"

# ------------------------------------------------
# Task 5: Create Monitoring Dashboard
# ------------------------------------------------
show_progress "Creating Monitoring Dashboard..."

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
# Task 6 & 7: Restart VM to Generate Logs
# ------------------------------------------------
show_progress "Restarting VM to generate traffic and logs..."

gcloud compute instances stop lamp-1-vm --zone=$ZONE
sleep 10
gcloud compute instances start lamp-1-vm --zone=$ZONE

echo -e "${GREEN}${BOLD}=================================================${RESET}"
echo -e "${GREEN}${BOLD}    Lab Setup Completed Successfully! 🚀        ${RESET}"
echo -e "${GREEN}${BOLD}=================================================${RESET}"
echo ""
echo -e "${BLUE}${BOLD}Final Step:${RESET} Go back to the lab and click ${YELLOW}Check My Progress${RESET} for all tasks."
echo ""
echo -e "${YELLOW}${BOLD}Join GC_2026 Community:${RESET} https://chat.whatsapp.com/K9d9xZNy2YqBqu6wvGEh2h"
echo -e "${MAGENTA}${BOLD}Happy Learning!${RESET}"
echo -e "${GREEN}${BOLD}=================================================${RESET}"

# Cleanup
rm -f uptime-check.json email-channel.json alert-policy.json dashboard.json
