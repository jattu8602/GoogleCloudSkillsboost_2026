#!/bin/bash
# Define rich color variables
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

# Background colors
BG_BLACK=$(tput setab 0)
BG_RED=$(tput setab 1)
BG_GREEN=$(tput setab 2)
BG_YELLOW=$(tput setab 3)
BG_BLUE=$(tput setab 4)
BG_MAGENTA=$(tput setab 5)
BG_CYAN=$(tput setab 6)
BG_WHITE=$(tput setab 7)

# Text effects
BOLD=$(tput bold)
DIM=$(tput dim)
BLINK=$(tput blink)
REVERSE=$(tput rev)
RESET=$(tput sgr0)

#----------------------------------------------------start--------------------------------------------------#


echo "${BG_BLUE}${WHITE}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║   🚀 Google Cloud Healthcare API Lab           ║"
echo "║                                                            ║"
echo "║   📺 Subscribe to:                                        ║"
echo "║   ${BLINK}https://youtube.com/@drabhishek.5460${RESET}${BG_BLUE}${WHITE}${BOLD}               ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo "${RESET}"

# Section header function
section() {
    echo ""
    echo "${BG_MAGENTA}${WHITE}${BOLD}»»» $1 «««${RESET}"
    echo ""
}

# Starting execution
section "INITIALIZING ENVIRONMENT"
echo "${BOLD}${GREEN}✓${RESET} ${YELLOW}Setting project variables...${RESET}"
export PROJECT_ID=$(gcloud config get-value project)
export DATASET_ID=dataset1
export FHIR_STORE_ID=fhirstore1
export DICOM_STORE_ID=dicomstore1
export HL7_STORE_ID=hl7v2store1

# Enable APIs
section "ENABLING REQUIRED APIS"
echo "${BOLD}${GREEN}✓${RESET} ${CYAN}Enabling Google Cloud services...${RESET}"
gcloud services enable compute.googleapis.com container.googleapis.com \
    dataflow.googleapis.com bigquery.googleapis.com pubsub.googleapis.com \
    healthcare.googleapis.com

# Create Healthcare dataset
section "CREATING HEALTHCARE DATASET"
echo "${BOLD}${GREEN}✓${RESET} ${MAGENTA}Creating healthcare dataset...${RESET}"
gcloud healthcare datasets create dataset1 --location=${REGION}
sleep 30  # Allow time for dataset creation

# Configure IAM permissions
section "CONFIGURING IAM PERMISSIONS"
PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID --format="value(projectNumber)")
SERVICE_ACCOUNT="service-${PROJECT_NUMBER}@gcp-sa-healthcare.iam.gserviceaccount.com"

echo "${BOLD}${GREEN}✓${RESET} ${BLUE}Assigning BigQuery admin role...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/bigquery.admin"

echo "${BOLD}${GREEN}✓${RESET} ${BLUE}Assigning Storage admin role...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/storage.objectAdmin"

echo "${BOLD}${GREEN}✓${RESET} ${BLUE}Assigning Healthcare admin role...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/healthcare.datasetAdmin"

echo "${BOLD}${GREEN}✓${RESET} ${BLUE}Assigning Pub/Sub publisher role...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/pubsub.publisher"

# Setup Pub/Sub
section "CONFIGURING PUB/SUB"
echo "${BOLD}${GREEN}✓${RESET} ${YELLOW}Creating HL7 topic...${RESET}"
gcloud pubsub topics create projects/$PROJECT_ID/topics/hl7topic

echo "${BOLD}${GREEN}✓${RESET} ${YELLOW}Creating HL7 subscription...${RESET}"
gcloud pubsub subscriptions create hl7_subscription --topic=hl7topic

# Create HL7 store
section "CREATING HL7 STORE"
echo "${BOLD}${GREEN}✓${RESET} ${GREEN}Creating HL7v2 store with notifications...${RESET}"
gcloud healthcare hl7v2-stores create $HL7_STORE_ID \
    --dataset=$DATASET_ID \
    --location=$REGION \
    --notification-config=pubsub-topic=projects/$PROJECT_ID/topics/hl7topic

# Completion message
echo ""
echo "${BG_GREEN}${BLACK}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║   🎉 ${WHITE}LAB COMPLETED SUCCESSFULLY!${BLACK}                      ║"
echo "║                                                            ║"
echo "║   ${WHITE}For more cloud tutorials:${BLACK}                           ║"
echo "║   ${BLINK}${WHITE}Subscribe to Dr. Abhishek's YouTube Channel${RESET}${BG_GREEN}${BLACK}${BOLD}  ║"
echo "║   ${WHITE}https://youtube.com/@drabhishek.5460${BLACK}                ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo "${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#
