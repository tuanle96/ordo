# Ordo

Ordo is a backend-first monorepo for an Odoo Community mobile product.

## Source of truth

- Client strategy: `SwiftUI` on iOS
- Backend strategy: `NestJS` on Node.js
- Shared contracts: TypeScript package under `shared/`
- Product requirements: `prd.md`

> Note: `prd.md` still contains an outdated roadmap line mentioning Flutter + FastAPI. For implementation, this repository follows the architecture and tech-stack sections that specify SwiftUI + NestJS.

## Repository layout

- `backend/` — NestJS API and Odoo integration seams
- `shared/` — shared contracts for auth, schema, records, and API envelopes
- `docs/` — project and engineering documentation
- `plans/` — implementation plans and reports
- `prd.md` — product requirements document
- `odoo-src/` — vendored Odoo source trees used as reference only

## Current handoff

Handoff 4 is currently focused on test-first hardening after the live completion of Handoffs 2 and 3.

Already shipped and verified:

- Auth module with `POST /auth/login` and `GET /auth/me`
- JWT guard and strategy with Bearer token extraction
- Odoo version detection (17, 18, 19) via `/web/webclient/version_info`
- Session-backed Odoo reads for `GET /schema/:model`, `GET /records/:model`, `GET /records/:model/:id`, and `GET /search/:model`
- Local Dockerized Odoo 17/18/19 validation stack under `odoo-instances/`
- Automated backend regression tests for health, auth, schema, records, search, and the Odoo 19 `group_ids` compatibility fallback

Still intentionally out of scope:

- refresh token rotation and logout invalidation
- Redis/Bull/WebSocket runtime wiring
- record write endpoints and action execution
- iOS app scaffold
- dashboard aggregation beyond a tiny future slice

## Quick start

### Prerequisites

- Node.js 22 LTS
- npm 10+

### Install

Run from the repository root:

`npm install`

### Build

`npm run build`

### Run backend

`npm run dev:backend`

### Run tests

`npm run test`

### Health check

After the backend starts:

`GET http://localhost:3000/health`

### Optional local Odoo validation stack

From `odoo-instances/`:

`docker compose up -d --build`

## Documentation

- `docs/project-overview-pdr.md`
- `docs/codebase-summary.md`
- `docs/system-architecture.md`
- `docs/code-standards.md`
- `docs/project-roadmap.md`
- `docs/project-changelog.md`
- `docs/deployment-guide.md`