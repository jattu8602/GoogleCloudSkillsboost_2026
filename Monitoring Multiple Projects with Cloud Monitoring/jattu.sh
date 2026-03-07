#!/bin/bash

# GC_2026 Arcade Shell Script - jattu.sh
# Lab: Monitoring Multiple Projects with Cloud Monitoring

# Exit on error
set -e

# --- Color Definitions ---
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`
BOLD=`tput bold`
RESET=`tput sgr0`

# --- Design Elements ---
BANNER_TOP="╔═══════════════════════════════════════════════════╗"
BANNER_MID="║                                                   ║"
BANNER_BTM="╚═══════════════════════════════════════════════════╝"

function show_banner() {
    echo -e "${BLUE}${BOLD}${BANNER_TOP}${RESET}"
    echo -e "${BLUE}${BOLD}║           GOOGLE CLOUD ARCADE 2026                ║${RESET}"
    echo -e "${BLUE}${BOLD}║   Monitoring Multiple Projects - Automation       ║${RESET}"
    echo -e "${BLUE}${BOLD}${BANNER_BTM}${RESET}"
}

function show_progress() {
    echo -e "${YELLOW}${BOLD}[PROGRESS]${RESET} ${CYAN}$1${RESET}"
}

# --- Initialization ---
clear
show_banner
echo ""

# 1. Project Selection Logic
show_progress "Fetching available GCP projects..."
PROJECT_LIST=$(gcloud projects list --format="value(projectId)")

echo -e "${GREEN}${BOLD}Available Projects:${RESET}"
gcloud projects list --format="table(projectId,name)"
echo ""

while true; do
    echo -e -n "${MAGENTA}${BOLD}✍️ Enter PROJECT_2 ID (the second project): ${RESET}"
    read PROJECT_2
    if [[ "$PROJECT_LIST" =~ (^|[[:space:]])"$PROJECT_2"($|[[:space:]]) ]]; then
        break
    else
        echo -e "${RED}${BOLD}❌ Error: Invalid project ID. Please choose from the list above.${RESET}"
    fi
done

show_progress "Identifying PROJECT_1 (Host Project)..."
PROJECT_1=$(echo "$PROJECT_LIST" | grep -v "^$PROJECT_2$" | head -n 1)

if [[ -z "$PROJECT_1" ]]; then
    echo -e "${RED}${BOLD}⚠️ Error: Could not identify a host project (PROJECT_1).${RESET}"
    exit 1
fi

export PROJECT_1
export PROJECT_2

# Display Selection Table
echo ""
echo -e "${BLUE}${BOLD}┌──────────────────────┬─────────────────────────────────┐"
echo -e "│     Variable         │              Value              │"
echo -e "├──────────────────────┼─────────────────────────────────┤"
printf "│ %-20s │ %-31s │\n" "PROJECT_1 (Host)" "$PROJECT_1"
printf "│ %-20s │ %-31s │\n" "PROJECT_2 (Target)" "$PROJECT_2"
echo -e "└──────────────────────┴─────────────────────────────────┘${RESET}"
echo ""

# 2. Configure Environment
show_progress "Switching to PROJECT_2: $PROJECT_2..."
gcloud config set project $PROJECT_2 --quiet

show_progress "Detecting default zone..."
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null || echo "us-central1-a")

# 3. Create Infrastructure
show_progress "Creating VM instance 'instance2' in $PROJECT_2..."
if gcloud compute instances describe instance2 --zone=$ZONE &>/dev/null; then
    show_progress "VM 'instance2' already exists. Skipping creation."
else
    gcloud compute instances create instance2 \
        --zone=$ZONE \
        --machine-type=e2-medium \
        --quiet
fi

# ------------------------------------------------
# Manual Step Prompt
# ------------------------------------------------
echo ""
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════╗"
echo -e "║              MANUAL CONFIGURATION              ║"
echo -e "╚═══════════════════════════════════════════════════╝${RESET}"
echo -e "${WHITE}Please follow these steps in the Cloud Console:"
echo -e "1. Go to Monitoring > Settings > Metrics Scope."
echo -e "2. Add PROJECT_1 to the scope of PROJECT_2."
echo -e "3. Create a Group named '${BOLD}DemoGroup${RESET}${WHITE}'."
echo -e "4. Set up an Uptime Check named '${BOLD}DemoGroup uptime check${RESET}${WHITE}'."
echo -e "5. Return here once finished.${RESET}"
echo ""

while true; do
    echo -e -n "${YELLOW}${BOLD}🤔 Have you completed the manual setup? [Y/N]: ${RESET}"
    read -r user_input
    case "$user_input" in
        [Yy])
            echo -e "${GREEN}${BOLD}Proceeding to finalize monitoring...${RESET}"
            break
            ;;
        [Nn])
            echo -e "${RED}${BOLD}🛑 Please complete the required setup first.${RESET}"
            ;;
        *)
            echo -e "${MAGENTA}${BOLD}❌ Invalid input. Please answer Y or N.${RESET}"
            ;;
    esac
done

# 4. Finalize Monitoring Policy
show_progress "Generating and applying monitoring policy..."

cat > monitoring_policy.json <<EOF
{
  "displayName": "Uptime Check Policy",
  "conditions": [
    {
      "displayName": "VM Instance - Check passed",
      "conditionAbsent": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_FRACTION_TRUE"
          }
        ],
        "duration": "300s",
        "trigger": { "count": 1 }
      }
    }
  ],
  "combiner": "OR",
  "enabled": true
}
EOF

# Create policy if it doesn't exist
if gcloud alpha monitoring policies list --filter='displayName="Uptime Check Policy"' --format='value(name)' | grep -q 'projects/'; then
    show_progress "Monitoring policy already exists. Skipping."
else
    gcloud alpha monitoring policies create --policy-from-file="monitoring_policy.json" --quiet
fi

# Cleanup
rm -f monitoring_policy.json

echo ""
echo -e "${GREEN}${BOLD}=================================================${RESET}"
echo -e "${GREEN}${BOLD}    Lab Setup Completed Successfully! 🚀        ${RESET}"
echo -e "${GREEN}${BOLD}=================================================${RESET}"
echo ""
echo -e "${BLUE}${BOLD}Final Step:${RESET} Go back to the lab console and click ${YELLOW}Check My Progress${RESET}."
echo ""
echo -e "${YELLOW}${BOLD}Join GC_2026 Community:${RESET} https://chat.whatsapp.com/K9d9xZNy2YqBqu6wvGEh2h"
echo -e "${MAGENTA}${BOLD}Happy Learning!${RESET}"
echo -e "${GREEN}${BOLD}=================================================${RESET}"
