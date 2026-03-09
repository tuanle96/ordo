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

## Handoff 6 architecture scope (Phase 03)

Handoff 6 Phase 03 adds iOS form save and validation:

- **Refresh-aware auth retry** before authenticated record writes; `AppState.withAuthenticatedToken()` transparently refreshes expired tokens via `POST /auth/refresh`
- **Dirty state tracking** via `FormDraft.isDirty()` comparing current field values to baseline; `FormDraft.changedValues()` extracts only modified fields for efficient PATCH payloads
- **Required-field validation** for `char`, `text`, and `selection` types (required `boolean` always valid); validation errors collected before API call and displayed inline
- **Save/discard UX** with edit mode entering on button tap; `Save` and `Cancel` buttons visible only when form is in edit mode; discard confirmation dialog prevents accidental data loss
- **Canonical record sync** after mutation response: record replaced, draft rebuilt from canonical response, cache updated, edit mode exited
- **iOS unit + UI test coverage** (16/16 tests passing) for dirty state, validation, save success/failure, cancel/discard, and edit mode visibility rules

## Handoff 6 architecture scope (Phase 04)

Handoff 6 Phase 04 adds relation editing and disciplined model expansion:

- **`many2one` editor path** with modal search/select/clear UI powered by the existing backend `/search/:model` contract
- **Local relation value representation** kept display-friendly in the draft layer while mutation payloads normalize to scalar relation IDs for PATCH semantics
- **ModelRegistry expansion** from `res.partner` to `crm.lead` and a narrow `sale.order` slice using model-specific row-summary field sets
- **Fixture-backed UI transport coverage** for schema/list/detail/update flows across all three supported browse models
- **Scope discipline** preserved by explicitly deferring `one2many` and `many2many` editors, order-line editing, and wizard-heavy flows

## Handoff 6 architecture scope (Phase 05)

Handoff 6 Phase 05 hardens the shipped write slice instead of widening it:

- **Explicit clear semantics** in `FormDraft` so cleared scalar/relation fields serialize to `.null` mutations instead of silently reusing baseline values
- **Inline save-failure handling** in the detail screen so mutation errors preserve edit mode, draft state, and loaded record context
- **Targeted regression coverage** for discard confirmation, save failure, and relation normalization edge cases
- **Repository status cleanup** so roadmap, changelog, README, and legacy plan files align with the completed write-capable Phase 1 state

## Phase 2 architecture scope (Phase 01)

Phase 2 Phase 01 moves backend session persistence from single-process memory into shared infrastructure:

- **Redis-backed Odoo session store** replaces the in-memory `Map`, using TTL-backed keys as the canonical source of session expiry truth
- **Shared Redis provider module** (`RedisModule` + `RedisService`) centralizes connection lifecycle so later schema-cache work reuses the same path instead of creating a second client stack
- **Async session-store integration** keeps auth, schema, and record flows fail-closed while preserving their existing public API surface
- **Lazy connection + safe shutdown** support both runtime reconnect scenarios and test-app teardown without requiring a live Redis daemon for unit/E2E defaults
- **Multi-instance readiness** improves because active upstream Odoo session handles can now survive backend restarts rather than being lost with process memory

## Phase 2 architecture scope (Phase 02)

Phase 2 Phase 02 adds the first Redis-backed performance layer on top of that foundation:

- **Read-through schema caching** for `GET /schema/:model` stores the final `MobileFormSchema` payload rather than intermediate XML/parser state
- **Conservative cache keys** include tenant, user, version, language, and model dimensions to avoid leaking form differences across Odoo instances or user contexts
- **Fixed 1 hour TTL** keeps the behavior simple and predictable; this phase intentionally does not add invalidation endpoints or per-model tuning knobs
- **Fail-open cache behavior** means Redis read/write problems degrade to live schema generation with warnings instead of interrupting API correctness
- **Schema-local cache helper** (`SchemaCacheService`) keeps the optimization close to the schema module instead of introducing a premature generic caching abstraction

## Phase 2 architecture scope (Phase 03)

Phase 2 Phase 03 hardens the unauthenticated HTTP edge instead of widening features:

- **Route-level throttling** applies only to `POST /auth/login` and `POST /auth/refresh`, keeping normal authenticated record/schema traffic unaffected
- **Environment-driven auth limits** let deployment environments tune login and refresh burst ceilings without changing request/response contracts
- **Explicit CORS bootstrap policy** centralizes browser-origin handling in `configureHttpApp()` rather than leaving CORS behavior implicit
- **Fail-closed preflight handling** omits CORS allow headers for unlisted origins, shrinking the browser attack surface while still allowing localhost during dev/test

## Phase 2 architecture scope (Phase 04)

Phase 2 Phase 04 makes backend behavior observable without dragging in a full observability platform:

- **Pino as the single logging engine** for JSON application logs plus HTTP request lifecycle logging
- **Central redaction policy** prevents auth headers, cookies, passwords, refresh tokens, and upstream Odoo cookie material from leaking into logs
- **Request ID propagation** via `x-request-id` gives each HTTP log line a lightweight correlation handle without introducing tracing infrastructure
- **Test-safe logging mode** disables noisy request logging in `NODE_ENV=test` so Jest output stays readable and deterministic
- **Bounded structured service events** replace ad-hoc string logs for Redis connectivity, schema-cache failures, upstream Odoo failures, and exception handling

## Phase 2 architecture scope (Phase 05)

Phase 2 Phase 05 widens regression confidence without changing the shipped runtime architecture:

- **Focused iOS unit-test expansion** adds dedicated suites for browse view-model state, detail view-model state, recent-items persistence, and an extra auth refresh failure path
- **Serialized Swift Testing for state-heavy suites** reduces false negatives caused by shared static transport handlers while keeping assertions at the state/output level instead of internal observer mechanics
- **Recent-items UI instrumentation** adds the targeted accessibility seams needed to exercise the relaunch flow without broadening the whole UI matrix
- **Explicit known-boundary handling** keeps the remaining recent-items relaunch UI nondeterminism documented for the next iOS phase rather than forcing the later `@Observable` refactor to absorb test instability that predates it

## Phase 2 architecture scope (Phase 06A/06B)

Phase 2 Phase 06A/06B closes the recent-items relaunch seam first, then pilots Swift Observation on the smallest shared-state holder:

- **Deterministic relaunch seam** uses the isolated `com.ordo.app.ui-tests` defaults suite plus targeted app-shell/login/detail accessibility hooks so recent-items persistence can be validated across relaunch without cross-run pollution
- **`RecentItemsStore` observation pilot** replaces `ObservableObject` / `@Published` with `@MainActor` + `@Observable` while keeping ordering, persistence, and clear behavior unchanged
- **Validated root injection pattern** keeps `AppState` on the legacy `EnvironmentObject` path for now, but moves recent-items ownership to `@State` in `OrdoApp` with typed `.environment(...)` consumption in `HomeView` and `RecordDetailView`
- **Explicit widening gate** means Phase 07 can now focus on `AppState`, feature view models, and `FormDraft` using a proven observation pattern instead of re-solving the recent-items seam

## Dynamic form hardening scope (2026-03-08)

The current dynamic-form slice hardens modifier correctness without attempting full Odoo onchange parity:

- **Additive modifier-rule schema contract** preserves legacy flat `invisible` conditions while adding recursive `condition` / `and` / `or` / `not` / `constant` trees for `invisible`, `readonly`, and `required`
- **Backend modifier parsing** now handles nested boolean expressions plus Odoo-style prefix-domain arrays, then merges simple container invisibility and `states`-based visibility into emitted field/button metadata
- **iOS modifier-aware rendering and validation** evaluates visibility, readonly state, and required rules against current draft values so edit mode and local validation track dynamic schema state more closely
- **Specific Odoo error translation** now maps common upstream permission, missing-record, and business-validation failures into clearer HTTP responses before they reach the mobile client
- **Explicit non-goal retained**: no full onchange engine yet; server-driven onchange still needs round-trip mutation previews, dependency ordering, and draft-merge semantics beyond this hardening slice

## Odoo onchange foundation scope (2026-03-08)

The current onchange architecture now covers the first honest server-backed slice without claiming full Odoo parity:

- **Explicit shared onchange contracts** (`OnchangeRequest`, `OnchangeResult`, `OnchangeWarning`, `OnchangeFieldMeta`) define a narrow transport for trigger field, current draft values, optional record identity, returned values, warnings, and domains
- **Backend orchestration path** adds `POST /records/:model/onchange`, which resolves the upstream Odoo session, fetches a fields spec, calls Odoo's `onchange`, and normalizes value/warning/domain payloads fail-closed before returning them to iOS
- **Schema-declared trigger metadata** means only fields explicitly marked by the parsed mobile schema participate in the first rollout; this avoids pretending every field/widget/context side effect is supported
- **iOS draft-merge lifecycle** centralizes edits in `RecordDetailViewModel`, debounces text-like changes, cancels superseded requests, and merges returned values through `FormDraft` with field-version protection so stale responses cannot overwrite newer user edits
- **Current support boundary is narrow by design**: inline warning display and stored returned domains are supported, but broad relation-editor domain application, offline replay, and full `one2many`/`many2many` parity remain deferred follow-up work

## Core-first generic form engine scope (2026-03-09)

The current Phase 01 core-first slice completes the minimum reusable form-engine path without widening into module-specific UI:

- **Canonical mobile-safe field matrix** now covers `char`, `text`, `html`, `integer`, `float`, `boolean`, `selection`, `date`, `datetime`, `many2one`, `many2many`, `monetary`, and a narrow `one2many` editor foundation
- **Generic renderer/editor parity** on iOS now exists across that matrix, including multiline HTML editing, currency-aware monetary display, debounced onchange for text-like monetary/html fields, and narrow inline `one2many` editing for supported scalar subfields
- **Generic draft normalization** in `FormDraft` now unifies scalar parsing, relation mutation encoding, object-shaped relation tolerance (`{ id, display_name/name }`), and Odoo command generation for narrow `one2many` create/update/delete flows
- **Line-level `one2many` validation** now catches missing required values for supported editable subfields before save while intentionally skipping collapsed existing lines that only carry `id`, preserving the current narrow server-record representation
- **Scope discipline remains explicit**: nested `many2one` / `many2many` inside `one2many`, broad returned-domain application, full x2many onchange parity, and wizard-like line workflows are still deferred follow-up work

## Core-first closeout foundations (2026-03-09)

The post-matrix closeout slice finishes the small but important CRUD/correctness gaps without stretching into media or workflow-specific widgets:

- **Create defaults stay narrow by contract**: backend record routes now expose `GET /records/:model/defaults` and forward only the requested mobile field names to Odoo `default_get`, returning raw `RecordData` instead of fabricating a full record shell
- **iOS create hydration is now server-backed**: `RecordDetailViewModel` loads schema first, derives a defaults field list from visible mobile fields plus optional statusbar state, hydrates the initial record from server defaults, and still falls back to manual entry if defaults loading fails
- **Delete parity is intentionally guarded**: the record-detail screen only enables destructive delete when a persisted record is idle, confirms intent before dispatch, removes the deleted record from recent-items state, and dismisses only after a successful backend response
- **`priority` remains a generic scalar field**: the iOS star control is only a view-layer affordance over the existing draft/change/save path, with no widget-specific backend contract or mutation semantics
- **Scope discipline remains explicit**: signature capture and statusbar tap-to-change are still deferred because they introduce broader transport or business-state concerns than this closeout slice is meant to solve; generic `binary`/document upload was intentionally split into the following Phase 02B slice

## Core-first image-first media widget slice (2026-03-09)

The first honest media step ships `image` support without pretending Ordo already has a full attachment platform:

- **Image support stays iOS-local and transport-light**: record detail now renders bounded read-only previews for `image` fields and edit mode offers choose/replace/clear via the native `PhotosPicker`, while save still reuses the existing create/update mutation payloads
- **No new backend contract was needed**: image edits travel as the existing `RecordData` string payload, so the current `POST /records/:model` and `PATCH /records/:model/:id` routes remain the only write transport for this slice
- **Client-side validation is the first guardrail**: `FormDraft` and the image editor reject invalid/oversize inline images before save, with the current MVP capped at **2 MB raw image data** to stay inside the existing request-body envelope while still being usable on-device
- **Cache and reload pressure stay explicit**: canonical post-save record reload and the 24-hour record cache still store the full returned base64 image payload, so this slice is intentionally limited to small images and record-detail surfaces only
- **Scope discipline remains explicit**: signature capture, camera/crop flows, and statusbar tap-to-change remain deferred; the follow-up generic `binary`/document upload slice shipped separately to avoid bloating the image-first MVP

## Core-first binary/document upload slice (2026-03-09)

The follow-up media step extends the generic form engine to small documents without turning Ordo into a general attachment platform:

- **Optional filename metadata is now part of the contract**: `FieldSchema.filenameField` travels from shared types through backend schema normalization into iOS decoding when Odoo form XML declares `filename="..."` on a `binary` field
- **Document editing stays on the existing mutation path**: iOS record detail now offers choose/replace/clear for generic `binary` fields through `UIDocumentPicker`, encoding the picked file as base64 and reusing the current create/update routes with no new backend endpoints
- **Honest filename persistence stays narrow**: if schema exposes a companion filename field, `FormDraft` tracks and mutates it alongside the binary payload; otherwise the selected filename is UI-only and read mode falls back to generic attachment text
- **Client-side safety remains explicit**: generic documents are capped at **1.5 MB raw bytes** before save, which keeps the current JSON body envelope viable after base64 expansion while surfacing clear inline validation errors
- **Scope discipline remains explicit**: broader attachment APIs, offline upload queueing, richer large-file fetch/export behavior, and chatter/media reuse all remain deferred follow-up work

## Core-first signature capture + inline preview/export slice (2026-03-09)

The next media step closes the honest inline preview/export gap while keeping Ordo far away from a general attachment platform:

- **`signature` remains a first-class generic field type** end to end on iOS record detail, with a narrow `PencilKit` capture sheet for draw / replace / clear and PNG/base64 persistence reused on the existing create/update mutation path
- **Read-only media rows now carry export metadata** so the renderer can surface bounded signature preview plus Preview / Export actions for already-loaded image, `binary`, and `signature` payloads without inventing a second transport contract
- **Preview/download stays entirely local** by writing temporary files from inline bytes and handing them to system Quick Look / share/export UI; no backend download/proxy endpoint or remote refetch path was added
- **Client-side safety remains explicit** with a `500 KB` raw PNG cap for signatures, the previously shipped `1.5 MB` document limit, and clear filename fallback logic when only payload bytes are available
- **Scope discipline remains explicit**: large-file/on-demand fetch, attachment history/index UI, chatter attachments, offline export queues, and non-signature ink features remain deferred

## Core-first statusbar tap-to-change slice (2026-03-09)

The first statusbar interaction slice increases Odoo parity without pretending the mobile client can infer arbitrary server-legal transitions:

- **Mutation stays action-backed**: tapping the eligible status chip routes into the existing workflow-action execution path, so Odoo server actions remain authoritative for permissions, business rules, and side effects
- **Eligibility is deliberately strict**: the client only enables statusbar tapping for persisted records whose header statusbar is selection-backed, exposes exactly two visible states, and currently has exactly one visible workflow action
- **Unsupported flows remain display-only**: many2one stage bars like `crm.lead.stage_id`, multi-action workflows, create mode, edit mode, and broader multi-state transitions do not opt into tap-to-change because the current contract does not prove a safe mapping
- **Refresh and cache coherence remain centralized**: successful taps reuse the existing confirmation, loading, post-action refresh, cache update, and unauthorized-to-sign-out behavior instead of inventing optimistic local state mutation
- **UX scope stays conservative**: the original workflow action button remains visible even in the eligible binary case, so the tappable chip is an alternate affordance rather than a replacement action model

## Deferred architecture

The following remain deferred beyond the current scope:

- sync engine
- notifications
- file proxying
- dashboard aggregation beyond a tiny future slice
- autosave and offline queued writes
- draft recovery after app relaunch
- expanded field type editors beyond the current Phase 01 matrix and narrow `one2many` scope