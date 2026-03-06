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

## Deferred architecture

The following remain deferred beyond the current Handoff 4 scope:

- sync engine
- notifications
- file proxying
- refresh token rotation
- persistent session storage
- dashboard aggregation beyond a tiny future slice