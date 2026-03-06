# Project Changelog

## 2026-03-06 (iOS Foundation — Offline Cache & Pagination)

### Added

- **FileCacheStore** actor for file-based offline persistence under `~/Library/Application Support/OrdoCache/`
  - JSON-encoded cache envelopes with absolute timestamps for schema, record details, and paginated lists
  - `loadSchema()`, `saveSchema()` for model metadata
  - `loadRecord()`, `saveRecord()` for record details
  - `loadListPage()`, `saveListPage()` for paginated record lists
  - `clear()` to remove all cached data
- **CachedValue** wrapper providing `relativeTimestamp` string (e.g., "2 hours ago") via `RelativeDateTimeFormatter`
- **List pagination for res.partner** with default 30 items per page
  - `loadMoreIfNeeded()` triggers next-page fetch when list scrolls to last visible item
  - Cache fallback when network unavailable; displays timestamp badge
  - `canLoadMore` flag reflects whether additional pages exist (determined by full-page return count)
- **Clear offline cache action** in Settings screen with destructive button variant
- **Cache status messages** on list/load-more views (e.g., "Showing saved data from 2 hours ago.")
- **Unit tests** for cache store (schema save/load, list pagination, encoding/decoding)

### Changed

- Record list view-model now integrates cache-first loading for initial page and load-more
- Settings screen expanded with Storage section for cache management
- AppState exposes `clearCache()` method scoped to cache store

### Verified

- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — build succeeds
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — unit test target passes

## 2026-03-06 (iOS Foundation)

### Added

- iOS native SwiftUI app scaffold with folder-first architecture under `ios/Ordo/` (App, Features, Shared, Networking, Persistence)
- Auth/login UI with Keychain-backed session persistence and `/auth/me` session restore at launch
- `APIClient` with async/await methods for auth, schema, records, and search routes; typed envelope decoding and error mapping
- Curated model registry with `res.partner` as first supported model
- Record list view with pagination and inline quick-search using `/search/:model`
- Schema-backed read-only record detail rendering with support for MVP field types (char, text, integer, float, boolean, selection, date, datetime, many2one, statusbar)
- Settings UI with server info, user profile display, and session management (sign out, cache clear)
- Home tab shell with connection status and recent items scaffolding
- iOS deployment target normalized to 17.0 across app, unit tests, and UI tests
- Removed Xcode template-only code (Item.swift)

### Changed

- iOS project structure reorganized from template defaults to feature-based organization

### Notes

- verified with `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — build succeeds
- `xcodebuild test` incomplete due to terminal interruption; full test suite run needed for final validation
- AppState restores previous authenticated session on app launch; routes to login if session invalid or expired
- APIClient integrates with shared TypeScript contracts from backend all six current endpoints
- Offline caching layer (read-through repositories, SwiftData cache entities, stale/offline UI states) deferred beyond this iteration

## 2026-03-06 (Backend completion)

### Added

- Jest + Supertest backend test foundation under `backend/test/`
- automated regression coverage for health, auth, schema, records, search, and the Odoo 19 `group_ids` fallback path

### Changed

- `backend` `npm test` now runs real automated tests instead of only TypeScript linting
- backend bootstrap configuration is shared between runtime and test app setup through `src/app.factory.ts`

### Notes

- verified with `npm run lint`, `npm run build`, and `npm run test` with 7 passing suites / 14 passing tests

### Added

- `odoo-instances/` local Docker Compose stack with shared PostgreSQL and live Odoo 17/18/19 instances on ports `38420`-`38423`
- per-version Odoo Dockerfiles and Postgres init SQL for repeatable local integration validation

### Changed

- Handoff 3 is now live-validated end-to-end against reachable Odoo 17/18/19 instances
- authenticated user profile loading now falls back from `groups_id` to `group_ids` for Odoo 19 compatibility

### Notes

- verified with `docker compose config`, `docker compose up -d --build`, database initialization for Odoo 17/18/19, `npm run build`, and live backend calls for `POST /auth/login`, `GET /auth/me`, `GET /schema/:model`, `GET /records/:model`, `GET /records/:model/:id`, and `GET /search/:model`

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

- verified with `npm install`, `npm run build`, backend runtime smoke tests, protected-route checks for missing upstream session behavior, and live successful schema/record/search validation against reachable Odoo 17/18/19 instances

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