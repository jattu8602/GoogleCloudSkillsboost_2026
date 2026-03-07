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

# Ask user input
read -p "Enter ZONE (example: us-east1-c): " ZONE
export ZONE

PROJECT_ID=$(gcloud config get-value project)
show_progress "Using project: $PROJECT_ID"

# ------------------------------------------------
# Set region automatically
# ------------------------------------------------
REGION=$(echo $ZONE | sed 's/-[a-z]$//')
gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# ------------------------------------------------
# Create VM
# ------------------------------------------------
show_progress "Creating LAMP VM instance..."

gcloud compute instances create lamp-1-vm \
--zone=$ZONE \
--machine-type=e2-medium \
--image-family=debian-12 \
--image-project=debian-cloud \
--tags=http-server \
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
--allow tcp:80 \
--target-tags=http-server \
--source-ranges=0.0.0.0/0 \
--description="Allow HTTP"

show_progress "Waiting 20 seconds for initialization..."
sleep 20

# ------------------------------------------------
# Get External IP
# ------------------------------------------------
EXTERNAL_IP=$(gcloud compute instances describe lamp-1-vm \
--zone=$ZONE \
--format='get(networkInterfaces[0].accessConfigs[0].natIP)')

show_progress "VM External IP: $EXTERNAL_IP"

# ------------------------------------------------
# Create uptime check
# ------------------------------------------------
show_progress "Creating uptime check..."

gcloud monitoring uptime create lamp-uptime-check \
--resource-type=uptime-url \
--hostname=$EXTERNAL_IP \
--path="/" \
--port=80

# ------------------------------------------------
# Create alert policy
# ------------------------------------------------
show_progress "Creating alert policy..."

cat > alert.json <<EOF
{
"displayName": "Inbound Traffic Alert",
"combiner": "OR",
"conditions": [{
"displayName": "Network traffic alert",
"conditionThreshold": {
"filter": "resource.type=\"gce_instance\" AND metric.type=\"agent.googleapis.com/interface/traffic\"",
"comparison": "COMPARISON_GT",
"thresholdValue": 500,
"duration": "60s",
"trigger": {"count": 1}
}
}]
}
EOF

gcloud alpha monitoring policies create --policy-from-file=alert.json

# ------------------------------------------------
# Create Dashboard
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
show_progress "Restarting VM to generate logs..."

gcloud compute instances stop lamp-1-vm --zone=$ZONE
sleep 15
gcloud compute instances start lamp-1-vm --zone=$ZONE

echo ""
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}    Lab Setup Completed Successfully! 🚀       ${NC}"
echo -e "${GREEN}===============================================${NC}"

echo -e "${BLUE}Check your progress in the lab now.${NC}"
echo ""
echo -e "${YELLOW}Join our WhatsApp community for updates: ${NC}https://chat.whatsapp.com/K9d9xZNy2YqBqu6wvGEh2h"
echo -e "${GREEN}Happy Learning with GC_2026!${NC}"
