# Project Changelog

## 2026-03-06

### Added

- in-memory upstream Odoo session-handle store with TTL
- session-aware Odoo dataset calls for protected reads
- `SchemaModule` with `GET /schema/:model`
- `RecordModule` with `GET /records/:model`, `GET /records/:model/:id`, and `GET /search/:model`
- fast-xml-parser based mobile form schema builder and simple invisible-condition parser

### Changed

- auth login now establishes and stores an opaque upstream Odoo session handle server-side
- JWT payload now carries an opaque `sessionHandle` claim while `GET /auth/me` strips it from public response
- Odoo v17 adapter now implements real schema/read/search behavior; v18/v19 inherit that implementation path

### Notes

- verified with `npm install`, `npm run build`, backend runtime smoke tests, and protected-route checks for missing upstream session behavior
- live successful schema/record/search validation against a reachable Odoo instance is still pending

## 2026-03-06

### Added

- root `.env` placeholder for local backend runtime secrets and defaults
- `AuthModule` with `POST /auth/login` and protected `GET /auth/me`
- JWT guard, strategy, and current-user decorator
- Odoo JSON-RPC transport with version detection and minimal user profile lookup

### Changed

- extended shared auth token claims for the first protected endpoint
- expanded backend env validation for JWT secrets and expirations
- made ConfigModule load `.env` reliably whether backend starts from repo root or workspace context

### Notes

- verified with `npm install`, `npm run build`, `npm test`, `/health`, unauthorized `/auth/me`, authorized `/auth/me`, and unreachable-upstream login error mapping
- local Odoo dev upstream at `127.0.0.1:38950` was not reachable during this session, so successful end-to-end login against a live Odoo instance is still pending

## 2026-03-06

### Added

- root `README.md`
- root `docs/` baseline
- `plans/` structure for formal implementation planning
- root npm workspace metadata
- `shared/` TypeScript contract package
- `backend/` NestJS scaffold with health endpoint and Odoo adapter seams

### Changed

- documented SwiftUI + NestJS as the implementation source of truth for this repository
- aligned repository foundation with backend-first Handoff 1 execution

### Notes

- verified with `npm run build`, `npm test`, and local `GET /health`
- real auth, Odoo RPC, schema parsing, and record APIs remain deferred to Handoff 2