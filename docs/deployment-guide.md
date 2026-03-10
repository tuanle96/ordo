# Deployment Guide

## Current status

Local development is fully supported. Production deployment guidance is still intentionally lightweight and should be treated as operational follow-up work, not as a finished platform-ops playbook.

## Local backend runtime

From the repo root, the verified local backend paths are:

- `docker compose up --build` — starts backend + Redis
- `npm run start:dev --workspace backend` — runs the backend locally if Redis is already available

The backend now depends on Redis for shipped behavior, not future behavior:

- Redis-backed upstream Odoo session persistence
- Redis-backed schema caching

Current mobile API surface includes:

- `GET /health`
- `POST /auth/login`
- `GET /auth/me`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /schema/:model`
- `GET /schema/:model/list`
- `GET /records/:model`
- `GET /records/:model/:id`
- `GET /records/:model/defaults`
- `POST /records/:model`
- `PATCH /records/:model/:id`
- `DELETE /records/:model/:id`
- `POST /records/:model/:id/actions/:actionName`
- `POST /records/:model/onchange`
- `GET /search/:model`

See `.env.example` and `README.md` for required runtime variables such as JWT secrets, Redis URL, request timeout, and Odoo upstream configuration.

## Local iOS runtime

Run the iOS app from `ios/Ordo.xcodeproj`, or validate the build with:

```bash
xcodebuild -project ios/Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build
```

The default backend base URL is configured in `ios/Ordo/app/app-config.swift`. The README's local API example currently points to `http://localhost:38424/api/v1/mobile` when using the repo Docker setup.

## Local Odoo validation

For live end-to-end validation against local Odoo instances:

```bash
cd odoo-instances
docker compose up -d --build
```

This repo ships local validation support for Odoo 17, 18, and 19.

## What is still not a finished deployment story

The following are still legitimate deployment follow-up items:

- polished TestFlight / App Store distribution guidance
- production container/orchestrator guidance for the backend
- secrets management and managed Redis guidance per environment
- staging/production rollout checklists and observability dashboards
- production-grade background sync / realtime / notification topology
- large-file/media serving strategy beyond the current inline/local preview-export path

## Current constraints

- live multi-version Odoo validation still requires reachable Odoo 17/18/19 instances
- iOS build requires Xcode 15+ on macOS
- offline support is still cache + queued mutation replay, not a full background sync engine
- multi-company switching and backend file-proxy/download flows are still outside the current shipped scope