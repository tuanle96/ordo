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

Handoff 2 implements the first real Odoo integration:

- Auth module with `POST /auth/login` and `GET /auth/me`
- JWT guard and strategy with Bearer token extraction
- Odoo version detection (17, 18, 19) via `/web/webclient/version_info`
- JSON-RPC transport for authentication and user profile lookup
- Protected endpoints with full error envelope mapping

Out of scope for this handoff:

- live Odoo instance validation (offline smoke tests complete)
- schema parsing and record CRUD
- refresh token rotation and logout invalidation
- Redis/Bull/WebSocket runtime wiring
- iOS app scaffold

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

### Health check

After the backend starts:

`GET http://localhost:3000/health`

## Documentation

- `docs/project-overview-pdr.md`
- `docs/codebase-summary.md`
- `docs/system-architecture.md`
- `docs/code-standards.md`
- `docs/project-roadmap.md`
- `docs/project-changelog.md`
- `docs/deployment-guide.md`