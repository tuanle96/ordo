# Deployment Guide

## Current status

Production deployment is out of scope for Handoff 2. Local development with auth is now fully functional.

## Local development

After `npm install` and `npm run dev:backend`, the following endpoints are available:

- `GET /health` — health check
- `POST /auth/login` — Odoo authentication (requires reachable upstream)
- `GET /auth/me` — protected current-user endpoint (requires Bearer token)

See `.env` for required runtime variables (JWT secrets, request timeouts, API prefix).

## Near-term expectation

Once all backend feature modules are stable, deployment guidance should document:

- runtime environment variables and secrets management
- Redis/Bull dependency (for sync, notifications, WebSockets)
- health and readiness checks for Odoo upstream connectivity
- container build steps and image optimization
- staging and production rollout strategy

## Current constraints

- Live Odoo upstream integration has only been offline-tested; requires a reachable Odoo 17/18/19 instance
- Redis and WebSocket support deferred to Handoff 3+