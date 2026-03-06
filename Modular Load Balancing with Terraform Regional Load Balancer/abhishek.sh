#!/bin/bash


# Color Definitions
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Display Header
clear
echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════════╗"
echo "║   🚀 Dr. Abhishek's Terraform LB Deployer  ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}📺 YouTube: https://youtube.com/@drabhishek.5460${NC}"
echo -e "${YELLOW}⭐ Please Subscribe for More Cloud Tutorials! ⭐${NC}"
echo

# Step 1: Authenticate and Set Project
echo -e "${BLUE}${BOLD}🔐 Step 1: Checking Authentication...${NC}"
gcloud auth list
echo

# Step 2: Set Region with Validation
set_region() {
  echo -e "${BLUE}${BOLD}🌍 Step 2: Configuring Region${NC}"
  
  # Try to get default region
  export REGION=$(gcloud config get-value compute/region 2>/dev/null)
  
  if [ -z "$REGION" ]; then
    # Get all available regions
    echo -e "${YELLOW}Available GCP Regions:${NC}"
    gcloud compute regions list --format="value(name)" | sort | pr -3 -t
    
    while true; do
      read -p "Enter your preferred region (e.g., us-central1): " REGION
      if gcloud compute regions describe $REGION &>/dev/null; then
        break
      else
        echo -e "${RED}Invalid region. Please try again.${NC}"
      fi
    done
    
    # Set region in gcloud config
    gcloud config set compute/region $REGION
  fi
  
  echo -e "${GREEN}Using region: ${BOLD}$REGION${NC}"
  export TF_VAR_region=$REGION
}

set_region

# Step 3: Clone Terraform LB Repository
echo
echo -e "${BLUE}${BOLD}📦 Step 3: Cloning Terraform Load Balancer Template...${NC}"
git clone https://github.com/GoogleCloudPlatform/terraform-google-lb
cd ~/terraform-google-lb/examples/basic || exit

# Step 4: Configure Project Variables
echo
echo -e "${BLUE}${BOLD}⚙️ Step 4: Configuring Project Settings...${NC}"
export GOOGLE_PROJECT=$(gcloud config get-value project)
export TF_VAR_project_id=$DEVSHELL_PROJECT_ID

# Step 5: Update Region in Terraform Files
echo
echo -e "${BLUE}${BOLD}🔄 Step 5: Updating Terraform Configuration...${NC}"
sed -i 's/us-central1/'"$REGION"'/g' variables.tf
echo -e "${GREEN}Updated region to ${BOLD}$REGION${NC} in variables.tf"

# Step 6: Initialize and Apply Terraform
echo
echo -e "${BLUE}${BOLD}🛠️ Step 6: Initializing Terraform...${NC}"
terraform init

echo
echo -e "${BLUE}${BOLD}📝 Step 7: Generating Execution Plan...${NC}"
terraform plan

echo
echo -e "${BLUE}${BOLD}🚀 Step 8: Deploying Load Balancer...${NC}"
yes | terraform apply --auto-approve

# Completion Message
echo
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════╗"
echo "║          🎉 Deployment Completed! 🎉          ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}Thank you for using Dr. Abhishek's Terraform script!${NC}"
echo -e "${YELLOW}Don't forget to subscribe to my YouTube channel for more tutorials!${NC}"
echo -e "${BLUE}https://youtube.com/@drabhishek.5460${NC}"
