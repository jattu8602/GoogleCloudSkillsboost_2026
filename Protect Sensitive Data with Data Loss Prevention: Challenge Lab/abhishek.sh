#!/bin/bash
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

echo
echo "${CYAN_TEXT}${BOLD_TEXT}============================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}🚀  WELCOME TO DR. ABHISHEK CLOUD TUTORIALS  🚀${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}============================================${RESET_FORMAT}"
echo
echo "${GREEN_TEXT}${BOLD_TEXT}Don't forget to subscribe to Dr. Abhishek's YouTube channel:${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@drabhishek.5460/videos${RESET_FORMAT}"
echo

read -p "${YELLOW_TEXT}${BOLD_TEXT}Enter BUCKET_NAME: ${RESET_FORMAT}" BUCKET_NAME

echo
echo "${CYAN_TEXT}${BOLD_TEXT}🛠️ Creating JSON payload for DLP API request...${RESET_FORMAT}"
cat > redact-request.json <<EOF
{
	"item": {
		"value": "Please update my records with the following information:\n Email address: foo@example.com,\nNational Provider Identifier: 1245319599"
	},
	"deidentifyConfig": {
		"infoTypeTransformations": {
			"transformations": [{
				"primitiveTransformation": {
					"replaceWithInfoTypeConfig": {}
				}
			}]
		}
	},
	"inspectConfig": {
		"infoTypes": [{
				"name": "EMAIL_ADDRESS"
			},
			{
				"name": "US_HEALTHCARE_NPI"
			}
		]
	}
}
EOF
echo "${GREEN_TEXT}✅ JSON payload created${RESET_FORMAT}"

echo
echo "${BLUE_TEXT}${BOLD_TEXT}📡 Sending request to DLP API...${RESET_FORMAT}"
curl -s \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  https://dlp.googleapis.com/v2/projects/$DEVSHELL_PROJECT_ID/content:deidentify \
  -d @redact-request.json -o redact-response.txt
echo "${GREEN_TEXT}✅ DLP API request completed${RESET_FORMAT}"

echo
echo "${GREEN_TEXT}${BOLD_TEXT}☁️ Uploading to Cloud Storage...${RESET_FORMAT}"
gsutil cp redact-response.txt gs://$BUCKET_NAME
echo "${GREEN_TEXT}✅ File uploaded to Cloud Storage${RESET_FORMAT}"

echo
echo "${CYAN_TEXT}${BOLD_TEXT}============================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}🎉 NOW FOLLOW THE VIDEO CAREFULLY !  🎉${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}============================================${RESET_FORMAT}"
echo
echo "${GREEN_TEXT}${BOLD_TEXT}Thank you for following Dr. Abhishek's Cloud Tutorial!${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}For more tutorials, please subscribe to:${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}${UNDERLINE_TEXT}https://www.youtube.com/@drabhishek.5460/videos${RESET_FORMAT}"
echo
