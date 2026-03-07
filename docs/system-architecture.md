# System Architecture

## Source of truth architecture

Ordo uses a backend-first architecture with these top-level pieces:

1. `SwiftUI` iOS client
2. `NestJS` middleware
3. Odoo servers accessed through version-aware adapters
4. shared TypeScript contracts as the transport source of truth

## Handoff 1 architecture scope

Handoff 1 establishes the minimum structure required to build forward safely:

- npm workspace root
- `shared/` contract package
- `backend/` NestJS app scaffold
- common HTTP envelope and health endpoint
- Odoo module interfaces and placeholders

## Handoff 2 architecture scope

Handoff 2 implements the first real Odoo-backed feature:

- `AuthModule` with login and current-user flows
- `JwtAuthGuard` with Passport strategy for Bearer token validation
- `OdooRpcService` for JSON-RPC 2.0 transport to Odoo
- Version detection and adapter factory routing (17, 18, 19)
- Token payload with user context (uid, db, odooUrl, version, lang, groups, name, email, tz)
- Full HTTP exception mapping and error envelope consistency
- Environment validation for JWT secrets and timeouts

## Handoff 3 architecture scope

Handoff 3 adds the first real Odoo-backed read surface:

- opaque backend-managed upstream Odoo session handles
- `SchemaModule` for `GET /schema/:model`
- `RecordModule` for `GET /records/:model`, `GET /records/:model/:id`, and `GET /search/:model`
- XML form parsing through `MobileSchemaBuilderService` and `ConditionParserService`
- version reuse where v18/v19 inherit the v17 adapter path unless proven otherwise

## Handoff 4 hardening scope

Handoff 4 currently hardens the shipped surface instead of widening it:

- shared runtime/test bootstrap via `src/app.factory.ts`
- Jest + Supertest automated regression tests
- focused unit coverage for Odoo 19 group field fallback, session TTL behavior, condition parsing, and schema mapping
- repo/docs alignment with the live-validated backend state

## iOS architecture scope (Handoff 5)

iOS client is now implemented and hardened with:

- `AppState` manager for app lifecycle, session restore, login, and user context
- `APIClient` async/await wrapper for backend routes (auth, schema, records, search)
- `KeychainSessionStore` for secure token and session persistence
- **File-based offline cache** via `FileCacheStore` actor storing JSON-encoded cache envelopes with timestamps for schema, record details, and paginated lists under `~/Library/Application Support/OrdoCache/`
  - **TTL-based eviction**: 7-day expiration for schemas, 24-hour expiration for record details and list pages
  - **Error resilience**: cache write failures logged via OSLog but do not block UI rendering; stale cache preferentially used on load-more network failures
  - **Safe file I/O**: atomic writes, directory creation on demand, expired entries pruned on load
- **Cache-first list pagination** for res.partner with default 30 items per page; load-more appends subsequent pages from API or fallback to cache
  - **Offset hardening**: `loadedOffsets` Set prevents duplicate page fetches; `nextOffset` computed from previous page size to detect boundaries
  - **Deduplication**: incoming records checked against existing `seenIDs` before merge to prevent ID collisions across stateless API calls
- **Relative timestamp display** on cached data showing age (e.g., "Showing saved data from 2 hours ago")
- Feature screens: auth (login), browse (list/search with pagination), record-detail, home, settings
- Settings screen with cache clear action (destructive)
- Environment-driven AppConfig for backend URL resolution
- **Deterministic UI testing** via `UITestURLProtocol` intercepting URLSession requests and `UITestAppStateFactory` providing in-process fixtures; mocked responses deterministic across test runs

## Handoff 6 architecture scope (Phase 01/02)

Handoff 6 Phase 01/02 adds auth refresh and backend record mutations:

- **Auth refresh** with dual JWT validation (separate access + refresh secrets) and session handle verification
- **Session touch lifecycle** via sliding-window TTL extension; expired sessions fail-closed requiring re-login
- **Record mutation surface** (POST/PATCH/DELETE + action) with shared DTOs and validation
- **Canonical post-write reads** after create/update ensuring client receives server-assigned defaults and computed fields
- **Action execution** with Odoo convention interpretation (`false` = no-op, truthy/record-dict = mutation occurred)
- **Adapter layer** for mutations with v17/v18/v19 version support

## Deferred architecture

The following remain deferred beyond the current scope:

- iOS refresh helper + 401 retry logic (Phase 03)
- sync engine
- notifications
- file proxying
- dashboard aggregation beyond a tiny future slice