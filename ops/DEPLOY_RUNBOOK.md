# Fractal5 Demo Deploy Runbook

Primary target:
- Project: `732190342674`
- Demo URL: `https://www.fractal5solutions.com/demo`
- Service: `dominion-demo`
- Region: `us-central1`

## Deploy sequence

1. Authenticate:

```bash
gcloud auth login --brief
gcloud config set project 732190342674
gh auth status
```

2. Confirm the secure build path:

```bash
./deploy_demo.sh
```

3. Verify the Cloud Run revision:

```bash
gcloud run services describe dominion-demo --project=732190342674 --region=us-central1
gcloud run revisions list --project=732190342674 --region=us-central1 --service=dominion-demo
```

4. Verify the public path:

```bash
curl -I https://www.fractal5solutions.com/demo
curl -s https://www.fractal5solutions.com/demo/healthz
```

5. Verify IAP policy:

```bash
gcloud iap web get-iam-policy \
  --project=732190342674 \
  --resource-type=backend-services \
  --service=dominion-demo-backend
```

## Expected state

- Cloud Run ingress is `internal-and-cloud-load-balancing`
- Unauthenticated requests to `/demo` are blocked by IAP
- The load balancer resolves to the DNS A record
- The demo page renders without console errors
- The store and health endpoints remain available

## Required IAM helpers

The Cloud Build service account also needs deploy privileges:

```bash
PROJECT_NUMBER="$(gcloud projects describe 732190342674 --format='value(projectNumber)')"
BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
gcloud projects add-iam-policy-binding 732190342674 --member="serviceAccount:${BUILD_SA}" --role="roles/artifactregistry.writer"
gcloud projects add-iam-policy-binding 732190342674 --member="serviceAccount:${BUILD_SA}" --role="roles/run.admin"
```

If the Cloud Run service later reads Secret Manager values, grant the runtime service account `roles/secretmanager.secretAccessor` as well.

## Failure triage

If the build fails:

```bash
gcloud builds list --project=732190342674 --limit=10
gcloud builds log BUILD_ID --project=732190342674
```

If Cloud Run fails:

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="dominion-demo"' --project=732190342674 --limit=100
```

If IAP fails:

```bash
gcloud iap web get-iam-policy --project=732190342674 --resource-type=backend-services --service=dominion-demo-backend
```

If DNS or TLS fails:

```bash
gcloud compute forwarding-rules list --global --project=732190342674
gcloud compute ssl-certificates list --project=732190342674
gcloud dns record-sets list --zone=fractal5-zone --project=732190342674
```
