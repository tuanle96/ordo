# Deployment Guide

## Current status

Production deployment remains out of scope. Local development for backend and iOS is fully functional.

## Backend local development

After `npm install` and `npm run dev:backend`, the following endpoints are available:

- `GET /health` — health check
- `POST /auth/login` — Odoo authentication (requires reachable upstream)
- `GET /auth/me` — protected current-user endpoint (requires Bearer token)
- `GET /schema/:model` — schema parser
- `GET /records/:model` — record list
- `GET /records/:model/:id` — record detail
- `GET /search/:model` — relation search

See `.env` for required runtime variables (JWT secrets, request timeouts, API prefix, Odoo upstream URLs).

## iOS local development

From `ios/`:

```bash
xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build
```

The app expects `backend/` running on `http://localhost:3000` by default; override via app settings or `app-config.swift`.

## Near-term expectation

Once iOS feature completeness is reached, deployment guidance should document:

- iOS TestFlight distribution and App Store submission
- backend container build and cloud deployment (AWS ECS, GCP Cloud Run, etc.)
- runtime environment variables and secrets management (API keys, JWT secrets, Odoo credentials)
- health and readiness checks for Odoo upstream connectivity
- Redis/Bull dependency (for sync, notifications, WebSockets) if needed
- database migrations and data freshness strategy
- staging and production rollout strategy

## Current constraints

- Live multi-version Odoo upstream integration has been tested locally but requires a reachable Odoo 17/18/19 instance
- iOS build requires Xcode 15+ on macOS
- Redis and WebSocket support deferred beyond current scope