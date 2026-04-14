#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-732190342674}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-dominion-demo}"
AR_REPO="${AR_REPO:-dominion-demo-repo}"
DOCKERFILE="${DOCKERFILE:-Dockerfile.production}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"
TAG="${TAG:-latest}"
DEMO_HOST="${DEMO_HOST:-https://www.fractal5solutions.com/demo}"

echo "== Fractal5 Demo Deploy =="
echo "Project:  ${PROJECT_ID}"
echo "Region:   ${REGION}"
echo "Service:   ${SERVICE_NAME}"
echo "Image:    ${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${SERVICE_NAME}:${TAG}"

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q '@'; then
  echo "ERROR: no active gcloud identity found. Run: gcloud auth login"
  exit 1
fi

gcloud config set project "${PROJECT_ID}" >/dev/null

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

for api in run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com compute.googleapis.com dns.googleapis.com iap.googleapis.com; do
  gcloud services enable "${api}" --quiet >/dev/null
done

if ! gcloud artifacts repositories describe "${AR_REPO}" --project="${PROJECT_ID}" --location="${REGION}" >/dev/null 2>&1; then
  gcloud artifacts repositories create "${AR_REPO}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --repository-format=docker \
    --description="Docker repo for Fractal5 demo"
fi

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${BUILD_SA}" \
  --role="roles/artifactregistry.writer" >/dev/null
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${BUILD_SA}" \
  --role="roles/run.admin" >/dev/null

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

gcloud builds submit "${BUILD_CONTEXT}" \
  --project="${PROJECT_ID}" \
  --config=cloudbuild.yaml \
  --substitutions="_SERVICE_NAME=${SERVICE_NAME},_REGION=${REGION},_AR_REPO=${AR_REPO},_DOCKERFILE=${DOCKERFILE},_BUILD_CONTEXT=${BUILD_CONTEXT},_TAG=${TAG}"

SERVICE_URL="$(gcloud run services describe "${SERVICE_NAME}" --project="${PROJECT_ID}" --region="${REGION}" --format='value(status.url)')"

echo
echo "Deployment complete."
echo "Service URL: ${SERVICE_URL}"
echo "Demo URL:    ${DEMO_HOST}"
echo
echo "Smoke checks:"
echo "  curl -I ${DEMO_HOST}"
echo "  curl -s ${SERVICE_URL}/healthz"
