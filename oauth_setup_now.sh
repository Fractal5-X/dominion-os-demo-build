#!/bin/bash
# PHI CHIEF AI - IMMEDIATE OAUTH EXECUTION
# Execute OAuth setup with provided credentials

echo "🤖 PHI CHIEF AI - EXECUTING OAUTH SOVEREIGNTY PROTOCOL"
echo "🔐 Client ID: Ov23ligsDU3M6CO1YcIT"
echo "🔐 Client Secret: ee3a3c7bf4a290f04c336dfe5d7cc2995e0f829b"
echo ""

echo "📝 Creating GitHub OAuth Client ID secret..."
echo -n "Ov23ligsDU3M6CO1YcIT" | gcloud secrets create github-oauth-client-id --project dominion-core-prod --data-file=-

echo "📝 Creating GitHub OAuth Client Secret secret..."
echo -n "ee3a3c7bf4a290f04c336dfe5d7cc2995e0f829b" | gcloud secrets create github-oauth-client-secret --project dominion-core-prod --data-file=-

echo "🔑 Granting service account permissions..."
gcloud secrets add-iam-policy-binding github-oauth-client-id --member="serviceAccount:447370233441-compute@developer.gserviceaccount.com" --role="roles/secretmanager.secretAccessor" --project dominion-core-prod --quiet

gcloud secrets add-iam-policy-binding github-oauth-client-secret --member="serviceAccount:447370233441-compute@developer.gserviceaccount.com" --role="roles/secretmanager.secretAccessor" --project dominion-core-prod --quiet

echo "🚀 Redeploying OAuth server with sovereignty..."
gcloud run services update phi-oauth-server --project dominion-core-prod --region us-central1 --set-secrets "GITHUB_CLIENT_ID=github-oauth-client-id:latest" --set-secrets "GITHUB_CLIENT_SECRET=github-oauth-client-secret:latest" --quiet

echo "✅ OAuth sovereignty established!"
echo "🎯 Ready for complete optimization..."
