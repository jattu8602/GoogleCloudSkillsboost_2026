#!/bin/bash

# GC_2026 Arcade Shell Script - jattu.sh
# Lab: Cloud Monitoring: Qwik Start

# Exit on error
set -e

# Define color variables
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`

BOLD=`tput bold`
RESET=`tput sgr0`

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}    GOOGLE CLOUD ARCADE 2026 - GC_2026        ${NC}"
echo -e "${BLUE}===============================================${NC}"

echo "${GREEN}${BOLD}Starting Execution${RESET}"

# Ask user input for Email
read -p "Enter your personal EMAIL for alerts: " USER_EMAIL
export USER_EMAIL

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Fallback if zone is not set
if [ -z "$ZONE" ]; then
    read -p "Enter ZONE (e.g., us-west1-a): " ZONE
    REGION=$(echo $ZONE | sed 's/-[a-z]$//')
fi

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION

# Create the instance with the necessary metadata and tags
gcloud compute instances create lamp-1-vm \
    --project=$DEVSHELL_PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-small \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --metadata=enable-oslogin=false \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --tags=http-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=lamp-1-vm,image=projects/debian-cloud/global/images/debian-10-buster-v20230629,mode=rw,size=10,type=projects/$DEVSHELL_PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any

# Create firewall rule to allow incoming HTTP traffic on port 80
gcloud compute firewall-rules create allow-http \
    --project=$DEVSHELL_PROJECT_ID \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

cat > prepare_disk.sh <<'EOF_END'
sudo apt-get update
sudo apt-get install -y apache2 php7.0
sudo service apache2 restart
EOF_END

gcloud compute scp prepare_disk.sh lamp-1-vm:/tmp --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet
gcloud compute ssh lamp-1-vm --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

export INSTANCE_ID=$(gcloud compute instances list --filter=lamp-1-vm --zones $ZONE --format="value(id)")

curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
  "https://monitoring.googleapis.com/v3/projects/$DEVSHELL_PROJECT_ID/uptimeCheckConfigs" \
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
      "project_id": "$DEVSHELL_PROJECT_ID",
      "zone": "$ZONE"
    },
    "type": "gce_instance"
  }
}
EOF
)"

cat > email-channel.json <<EOF_END
{
  "type": "email",
  "displayName": "GC_2026 Alert",
  "description": "Alert notification",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF_END

gcloud beta monitoring channels create --channel-content-from-file="email-channel.json"

# Get the channel ID
email_channel_info=$(gcloud beta monitoring channels list --filter='displayName="GC_2026 Alert"')
email_channel_id=$(echo "$email_channel_info" | grep -oP 'name: \K[^ ]+' | head -n 1)

cat > awesome.json <<EOF_END
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
            "alignmentPeriod": "300s",
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
    "$email_channel_id"
  ],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF_END

gcloud alpha monitoring policies create --policy-from-file="awesome.json"

# Final message
echo -e "\n${GREEN}${BOLD}You have successfully set up and monitored a VM with Cloud Monitoring. You've also created an uptime check, an alerting policy, and a dashboard and chart. You've seen how Cloud Logging reflects changes to your VM instance${RESET}"
echo -e "\n${YELLOW}Join our WhatsApp community for updates: ${NC}https://chat.whatsapp.com/K9d9xZNy2YqBqu6wvGEh2h"
echo -e "${GREEN}Happy Learning with GC_2026!${NC}"
#-----------------------------------------------------end----------------------------------------------------------#
