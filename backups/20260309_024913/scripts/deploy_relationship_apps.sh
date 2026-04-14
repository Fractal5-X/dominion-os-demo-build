#!/bin/bash
# Deploy Relationship Applications to Google Cloud

echo "☁️  Deploying relationship applications to Google Cloud Run..."

PROJECT_ID="dominion-os-1-0-main"
REGION="us-central1"

# Deploy CRM Application
echo "Deploying CRM application..."
gcloud run deploy dominion-crm \
  --source . \
  --platform managed \
  --region $REGION \
  --project $PROJECT_ID \
  --allow-unauthenticated \
  --set-env-vars "APOLLO_API_KEY=$APOLLO_API_KEY" \
  --memory 1Gi \
  --cpu 1 \
  --max-instances 10

# Deploy BIMS Application
echo "Deploying BIMS application..."
gcloud run deploy dominion-bims \
  --source . \
  --platform managed \
  --region $REGION \
  --project $PROJECT_ID \
  --allow-unauthenticated \
  --set-env-vars "GMAIL_API_KEY=$GMAIL_API_KEY,GOOGLE_DRIVE_API_KEY=$GOOGLE_DRIVE_API_KEY" \
  --memory 2Gi \
  --cpu 2 \
  --max-instances 10

# Deploy Relationship API
echo "Deploying Relationship API..."
gcloud run deploy dominion-relationships \
  --source . \
  --platform managed \
  --region $REGION \
  --project $PROJECT_ID \
  --allow-unauthenticated \
  --set-env-vars "APOLLO_API_KEY=$APOLLO_API_KEY,GMAIL_API_KEY=$GMAIL_API_KEY" \
  --memory 1Gi \
  --cpu 1 \
  --max-instances 5

echo "✅ Applications deployed successfully!"
