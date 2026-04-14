# Dominion OS Demo Build

Public-facing demo service repository for Dominion OS.

## Purpose

- Hosts demo UX and supporting demo APIs.
- Demonstrates `dominion-command-center` capabilities in a marketable SaaS presentation.
- Focuses on business overlays only for this stream.

## Core Demo Capabilities

- Dominion OS Core and top feature walkthroughs.
- Google Cloud SaaS integration surface for demo scenarios.
- Shapefile mapping workflows for geo/business visualization.
- Google API integrations for broader cloud-universe demonstrations.

## Governance

- This repo is serving-only and non-authoritative.
- Control plane and source-of-truth runtime authority remains in `dominion-command-center`.
- Demo content in this repo is intended for public presentation use.
- Production demo packaging must remain public-safe: no secrets, no tokens, no CRM/contact dumps, and no plain-source runtime payload in the final demo image.

## Proof Artifacts

- `DOMINION_OS_DEPLOYMENT_PROOF.md`
- `OPTIMAL_DEPLOYMENT_PROOF.md`
- `PRODUCTION_READINESS_PROOF.md`

## Runbook Notes

- Probe semantics for `/status` and `/api/v1/topology` are documented in `RUNBOOK_STATUS_PROBES.md`.
