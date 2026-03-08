# Project Changelog

## 2026-03-08 (iOS Create Flow & Primitive Editor Expansion)

### Added

- **iOS create-record flow** entered from browse lists via a toolbar `+` action and powered by the existing backend `POST /api/v1/mobile/records/:model` endpoint
- **Editable primitive field support** on iOS for `integer`, `float`, `date`, and `datetime` fields in the schema-driven form engine
- **Unit regression coverage** for numeric/temporal value normalization, format validation, editable-field routing, and create-mode mutation success

### Changed

- `RecordDetailView` / `RecordDetailViewModel` now support a schema-only create mode that starts in edit state, validates locally, posts mutations, then transitions into normal detail mode after canonical readback
- `FormDraft` now normalizes string input for numeric and temporal fields into stable mutation payloads before POST/PATCH submission
- Browse lists now expose a direct create entry point instead of remaining read/edit-only surfaces

### Verified

- **Known gap:** deterministic UI/E2E coverage for the new create flow is still pending; current validation is build + unit-test level only
- `xcodebuild -project ios/Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — iOS app builds cleanly
- `xcodebuild -project ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — iOS unit target passes, including the new create-flow and numeric/temporal validation coverage
- Independent code review found no blocking issues; remaining gap is lack of UI/E2E coverage for the new create flow in the current slice

### Notes

- This slice intentionally stops at unit/integration-style validation; a deterministic UI test for the end-to-end create flow remains recommended follow-up work
- Workflow action buttons and backend logout remain separate follow-up slices

## 2026-03-08 (Chatter MVP — Read Thread + Post Note)

### Added

- **Shared chatter contracts** (`ChatterMessage`, `ChatterAuthor`, `ChatterThreadResult`, `PostChatterNoteRequest`) for cross-platform typed communication
- **Backend chatter endpoints** at `GET /api/v1/mobile/records/:model/:id/chatter` (paginated thread read) and `POST /api/v1/mobile/records/:model/:id/chatter/note` (post internal note)
- **Odoo adapter delegation** with V17 `listChatter` and `postChatterNote` methods supporting pagination via `before` cursor and `limit` parameter
- **iOS chatter section** with lazy-loaded thread display, @Observable viewmodel, and send-note UX below the record form
- **Comprehensive test coverage** including backend E2E routes, backend service delegation, and iOS unit/UI validation

### Changed

- Records with `hasChatter == true` now surface a usable thread section instead of an unimplemented placeholder
- `hasChatter` field detection already existed in schema; this phase activates the transport layer

### Verified

- `npm run build` — shared + backend builds cleanly
- `npm test` — backend test suite passes (all chatter DTOs, route guards, adapter calls)
- `xcodebuild ... build` — iOS app builds without errors
- `xcodebuild ... -only-testing:OrdoTests test` — iOS chatter viewmodel tests pass (lazy load, send-note, thread refresh)
- Code review: production-ready for approved scope; security relies on JWT auth + Odoo's html_sanitize layer
- Tester validation: no blocking issues; medium-priority improvements (rate limiting, sanitization docs) deferred to Phase 2 hardening

### Notes

- MVP scope is deliberately narrow: read thread + post internal log note only
- Followers, activities, attachment-heavy chatter, and rich message types remain deferred to future phases
- All validation reports stored in `plans/reports/`: code-reviewer and tester summaries confirm clean merge-ready state

## 2026-03-08 (Dynamic Form Modifier Hardening & Odoo Error Specificity)

### Added

- **Additive modifier rule trees** in the shared schema contract for `invisible`, `readonly`, and `required` using `condition`, `and`, `or`, `not`, and `constant` nodes
- **Backend support** for nested boolean modifier expressions and Odoo-style prefix-domain arrays used by dynamic form rules
- **Recursive iOS modifier evaluation** so record-detail rendering and validation react to current draft values instead of only static schema booleans
- **More specific upstream Odoo error mapping** for common access-right, missing-record, and business-validation failures

### Changed

- `MobileSchemaBuilderService` now emits merged field/button modifier metadata and folds ancestor/container invisibility plus simple `states` visibility constraints into the schema payload
- `RecordDetailViewModel`, `SchemaRendererView`, and `FormDraft` now evaluate editability and required validation against current draft values instead of assuming static readonly/required flags
- Backend schema parsing moved beyond the original MVP single-regex `ConditionParserService` path and now supports nested rule trees while preserving legacy flat `invisible` conditions where possible
- Upstream Odoo exceptions no longer collapse most failures into a generic `502`; common permission and validation cases now surface clearer HTTP statuses/messages to the client

### Verified

- `npm run build --workspace shared` — shared contract package rebuilds cleanly with the new modifier types
- `npm run test --workspace backend` — backend suite passes (10 suites / 34 tests)
- `npm run build --workspace backend` — backend compiles after parser/schema/error-mapping changes
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — iOS app builds cleanly
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — Ordo unit-test target passes, including condition/modifier coverage

### Notes

- This slice intentionally **does not** implement full Odoo onchange parity; onchange still needs server round-trips, dependency tracking, and draft-merge semantics beyond the current safe scope
- Modifier support is materially broader than before, but it is still not a claim of full client-side parity with every Odoo expression, context reference, or XML edge case

## 2026-03-08 (iOS Form Editors & List Browsing Improvements — Phase 07)

### Added

- **Many2many editable tags picker** for record detail edit mode with add/remove tag flows backed by `/search/:model` endpoint
- **Browse table mode + sort** on iOS list screens with sortable column headers and toggle between table and grid layouts
- **Order-isolated list cache keys** for pagination so list pages are cached separately per sort order, preventing sort state mixing across navigations

### Changed

- `CacheKey.list` enum now includes `order` parameter in cache filename to prevent collisions between differently-sorted page fetches
- `RecordListViewModel` now tracks active sort order and passes it through pagination/cache flows
- Browse table headers now render clickable sort indicators with ascending/descending state persistence
- `EditableFieldFactory` now includes `many2many` field editors alongside `many2one` for full relation edit support
- Form fields of type `many2many` now render as responsive tag pickers in edit mode

### Verified

- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — iOS app builds without errors
- iOS unit tests pass with cache-key isolation and sort-state coverage
- Targeted UI tests validate many2many tag selection flow and sort column interactions
- List cache verification confirms order-specific cache entries persist correctly across navigations

### Notes

- Many2many editor supports search/select/add/remove tags; full nested picker UX remains deferred
- Sort state is local to current navigation context; multi-column sort remains future work
- Chatter threads, file upload, kanban/grouping views, and offline mutation queue remain deferred to later phases

## 2026-03-08 (Production Hardening — Phase 2 Phase 06A/06B iOS Recent-Items Determinism + Observable Pilot)

### Added

- **Recent-items relaunch determinism preflight** using the isolated `com.ordo.app.ui-tests` defaults suite plus targeted root/accessibility seams so relaunch assertions no longer depend on cross-run shared state
- **`RecentItemsStore` `@Observable` pilot** with `@MainActor` isolation, `@State` root ownership in `OrdoApp`, and typed environment injection into recent-items consumers

### Changed

- `RecentItemsStore` now uses Swift Observation instead of `ObservableObject` / `@Published` while preserving ordering, persistence, and clear semantics
- Recent-items relaunch validation moved from a known simulator boundary to a green targeted UI seam that can serve as the baseline for the broader Phase 07 migration

### Verified

- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — full iOS unit target passes after the `@Observable` pilot
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoUITests/OrdoUITests/testHomeShowsRecentlyViewedRecordAfterRelaunch test` — targeted relaunch UI regression passes with xcresult status `Success`

### Notes

- Phase 07 remains the first slice allowed to widen `@Observable` into `AppState`, feature view models, and `FormDraft`; 06A/06B intentionally stopped at the narrow recent-items seam

## 2026-03-07 (Production Hardening — Phase 2 Phase 05 iOS Test Hardening)

### Added

- **Focused iOS unit regression coverage** for `RecordListViewModel`, `RecordDetailViewModel`, `RecentItemsStore`, and an additional `AppState` refresh-failure edge case
- **Serialized Swift Testing isolation** for the three state-heavy suites that share static URLProtocol-based transport handlers
- **Recent-items UI regression path coverage** plus extra login/home/browse accessibility hooks used to investigate the relaunch flow

### Changed

- Phase 05 is now accepted at a **unit-green** milestone instead of waiting for a fully deterministic relaunch UI path in this simulator environment
- Recent-items ordering/cap/persistence confidence now lives primarily in the deterministic unit layer, with the remaining UI relaunch instability called out explicitly as follow-up work for the next iOS phase

### Verified

- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — iOS unit target passes after serializing the state-heavy suites

### Notes

- `OrdoUITests.testHomeShowsRecentlyViewedRecordAfterRelaunch()` remains nondeterministic in the current simulator environment and is intentionally documented as a known flaky/blocking boundary for the next iOS phase rather than a Phase 05 blocker

## 2026-03-07 (Production Hardening — Phase 2 Phase 04 Structured Logging)

### Added

- **Pino-based structured logging** for backend application logs plus `pino-http` request lifecycle logging with request IDs
- **Central redaction rules** covering authorization headers, cookies, passwords, refresh tokens, and upstream Odoo cookie material
- **Custom logger service** so backend logs emit JSON outside test mode while Jest remains quiet and deterministic

### Changed

- Nest bootstrap now buffers early logs and swaps to the structured logger during app configuration
- Redis, schema-cache, upstream Odoo, and exception handling logs now emit bounded structured events instead of loose string-only messages
- HTTP requests now carry `x-request-id` correlation IDs and structured method/path/status log lines in non-test environments

### Verified

- `npm run build --workspace backend` — backend compiles with the new logging stack
- `npm run test --workspace backend` — backend regression suite passes (10 suites / 28 tests) with quiet test output

### Notes

- This phase intentionally stops at local structured output; log shipping, metrics, and tracing remain deferred infrastructure concerns

## 2026-03-07 (Production Hardening — Phase 2 Phase 03 Auth Perimeter Hardening)

### Added

- **Route-scoped auth throttling** on `POST /auth/login` and `POST /auth/refresh` using Nest throttler with environment-driven limits and TTLs
- **Explicit CORS allowlist configuration** driven by `CORS_ALLOWED_ORIGINS`, with sane localhost allowances only in development/test environments
- **Auth hardening E2E coverage** for repeated login/refresh abuse and preflight behavior for allowed vs denied browser origins

### Changed

- Backend bootstrap now enables explicit CORS instead of relying on implicit defaults
- Public auth edge now returns `429` on burst abuse while keeping authenticated browse/detail routes untouched
- Unlisted browser origins now fail closed during preflight without `access-control-allow-origin` headers

### Verified

- `npm run build --workspace backend` — backend compiles with throttler and CORS wiring
- `npm run test --workspace backend` — backend regression suite passes (10 suites / 28 tests)

### Notes

- Current CORS policy is intentionally narrow and env-driven; this phase does not try to solve broader gateway/WAF policy concerns

## 2026-03-07 (Production Hardening — Phase 2 Phase 02 Redis Schema Cache)

### Added

- **Redis-backed schema cache** for `GET /schema/:model` responses with a fixed 1 hour TTL
- **`SchemaCacheService`** to own conservative cache-key construction (`odooUrl`, `db`, `version`, `uid`, `lang`, `model`) and keep caching logic local to the schema module
- **Schema cache regression coverage** for key shape, TTL, fail-open Redis error handling, and `SchemaService` cache hit/miss behavior

### Changed

- `SchemaService.getFormSchema()` now uses read-through caching: Redis lookup first, live Odoo schema generation on miss, then backfill into Redis
- Schema cache failures now log warnings and fall back to uncached generation instead of breaking schema reads

### Verified

- `npm run build --workspace backend` — backend compiles with schema cache wiring
- `npm run test --workspace backend` — backend regression suite passes (10 suites / 25 tests)

### Notes

- Schema cache intentionally accepts stale-by-TTL behavior for up to 1 hour; invalidation endpoints remain deferred to later hardening work

## 2026-03-07 (Production Hardening — Phase 2 Phase 01 Redis Session Store)

### Added

- **Redis-backed Odoo session persistence** replacing the process-local in-memory session `Map`; session handles now resolve through Redis TTL-backed keys instead of backend memory
- **Shared Redis module/service** built on `ioredis` so later phases can reuse the same connection path for schema caching and other backend hardening work
- **Redis env validation and sample config** covering `REDIS_URL`, connection timeout, key prefix, and session-key namespace defaults

### Changed

- `OdooSessionStoreService` now persists serialized `OdooSessionContext` blobs under namespaced Redis keys while keeping the same auth-facing `create/get/getOrThrow/touch/touchOrThrow/delete` behavior
- Auth, schema, and record services now await the Redis-backed session store without changing their public API contracts
- Redis client shutdown now handles lazy, not-yet-connected test app instances safely so Nest teardown does not fail in E2E runs

### Verified

- `npm run build --workspace backend` — backend compiles with the new Redis dependency and module wiring
- `npm run test --workspace backend` — backend regression suite passes (8 suites / 20 tests), including E2E teardown after the Redis lifecycle fix

### Notes

- This phase intentionally stops at session persistence; schema caching, auth rate limits, explicit CORS, and structured logging remain queued in later Phase 2 slices

## 2026-03-07 (Testing Hardening & Docs — Handoff 6 Phase 05)

### Added

- **iOS unit regression coverage** for explicit `many2one` clears and same-ID/different-label relation normalization behavior
- **iOS UI regression coverage** for discard confirmation (`Keep Editing` vs `Discard Changes`) and save-failure draft preservation

### Changed

- `RecordDetailView` now renders save failures inline on the detail screen when a record is already loaded, preserving edit state and unsaved draft data
- `FormDraft.setValue()` now persists explicit clears as `.null` so write payloads can actually remove existing scalar/relation values instead of falling back to baseline data
- Active Handoff 6 plan/docs and the legacy Handoff 4 plan status now reflect the completed write-capable Phase 1 slice

### Verified

- `npm run build` — root workspace build passes
- `npm test` — root workspace test suite passes (8 backend suites / 20 tests)
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — full iOS unit target passes
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoUITests/testDetailCancelFlowSupportsKeepEditingAndDiscard test` — discard confirmation path passes
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoUITests/testDetailSaveFailurePreservesEditStateAndDraft test` — save-failure path passes
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — iOS build passes

### Notes

- Full `OrdoUITests` remains susceptible to simulator launch flakiness in this environment, so Phase 05 validation focused on the critical write/discard/failure paths added in-session.

## 2026-03-07 (Relation Editors & Model Expansion — Handoff 6 Phase 04)

### Added

- **`many2one` editor flow** on iOS with search, select, and clear behavior backed by the existing `/search/:model` endpoint
- **Relation-aware JSON helpers** for display-friendly local values (`[id, label]`) and stable mutation payload normalization to scalar relation IDs
- **Expanded browse model support** for `crm.lead` and a narrow, header-only `sale.order` slice after the existing `res.partner` proof
- **Fixture-backed regression coverage** for relation search, relation persistence, model browse smoke coverage, and editable-field expectations

### Changed

- `FormDraft` now normalizes `many2one` values before diffing/saving and validates required relation fields locally
- `EditableFieldFactory` now treats supported `many2one` fields as first-class editable controls rather than read-only fallbacks
- UI test fixtures now serve schema/list/detail/PATCH flows for `res.partner`, `crm.lead`, and `sale.order`
- `ModelRegistry` now uses per-model title/subtitle/footnote field sets instead of a single hard-coded `res.partner` summary rule

### Verified

- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — unit tests pass
- `xcodebuild -project /Volumes/DATA/Developments/Odoo/Ordo/ios/Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoUITests/testSmokeLoginBrowseAndDetail -only-testing:OrdoUITests/testDetailMany2OneSaveFlowPersistsSelectedRelation test` — targeted UI tests pass
- Full `OrdoUITests` attempted in-session but one run hit a simulator launch denial from `SBMainWorkspace`; no app assertion/build failure was observed in that run

### Notes

- Phase 04 intentionally stops at `many2one`; `one2many` and `many2many` editors remain explicitly deferred
- `sale.order` support remains narrow by design: header-level fields plus reused relation-display/edit paths only

## 2026-03-07 (iOS Save Flow & Form Validation — Handoff 6 Phase 03)

### Added

- **Refresh-aware auth retry** before authenticated record writes; `AppState.withAuthenticatedToken()` ensures non-expired access token
- **Save/discard UX** on detail screen with `Save` and `Cancel` buttons visible only in edit mode; discard confirmation dialog prevents accidental loss
- **Dirty state tracking** via `FormDraft.isDirty()` and `FormDraft.changedValues()` for efficient PATCH payload generation
- **Required-field validation** for `char`, `text`, and `selection` (required `boolean` fields always valid); validation errors displayed inline before API call
- **Fixture-backed PATCH flow** via `APIClient.updateRecord()` calling backend canonical read after mutation; response syncs record/draft/cache
- **Unit + UI test coverage** (16/16 tests passing): FormDraftTests, validation, save success/failure, cancel/discard, edit mode visibility rules

### Architecture

- Save flow validates locally (required fields) → calls PATCH → receives canonical record response → rebuilds draft → exits edit mode → updates cache
- `RecordDetailViewModel` centralized save/error state management; UI remains pure observer
- Editable field types limited to supported subset (`char`, `text`, `boolean`, `selection`); unsupported types remain read-only
- Token refresh happens transparently; 401 triggers sign-out with clear messaging

### Verified

- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — app builds without errors
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' -only-testing:OrdoTests test` — 16 unit tests pass
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' -only-testing:OrdoUITests test` — critical UI tests pass (edit mode visibility, save persistence)
- Dirty tracking accurate; validation gates API calls; 401 refresh + retry prevents token expiry race conditions

### Notes

- Autosave, offline queued writes, and draft recovery deferred to future phases
- Backend remains authority for complex business validation; client-side validation is defensive only
- Delete CTA optional if kept simple; can be added in Phase 04 relation expansion

## 2026-03-07 (Backend Record Mutations & Auth Refresh — Handoff 6 Phase 01/02)

### Added

- **`POST /auth/refresh` endpoint** with `RefreshTokenDto` for access token rotation; validates both JWT and upstream session handle (fail-closed if expired)
- **Session touch lifecycle** via `OdooSessionStoreService.touch()` and `touchOrThrow()` for sliding-window TTL extension on refresh
- **Record mutation endpoints** for all core write operations:
  - `POST /records/:model` → create with canonical read-back of new record
  - `PATCH /records/:model/:id` → update with canonical read-back of modified record
  - `DELETE /records/:model/:id` → delete with `{ id, deleted: true }` confirmation
  - `POST /records/:model/:id/actions/:actionName` → action execution with optional record refresh
- **Shared mutation contracts** (`RecordMutationRequest`, `RecordMutationResult`, `DeleteRecordResult`, `RecordActionResult`) with strict DTO validation
- **Comprehensive E2E + unit test coverage** for all mutation endpoints and session refresh logic

### Architecture

- Dual JWT validation (separate access + refresh secrets) with session handle verification
- Adapter interface for mutations ensures consistent v17/v18/v19 support
- Canonical post-write reads guarantee client-server state synchronization essential for offline-first architecture
- Session store maintains in-memory context with TTL-based expiry and cleanup

### Verified

- TypeScript compiles without errors (shared + backend)
- All 20 tests pass (8 suites, 1.8s runtime)
- Security audit: JWT dual-secret strategy, input validation, error handling, session management
- API design: RESTful conventions, consistent response envelopes, idempotency semantics

### Notes

- iOS refresh helper + 401 retry logic deferred to Phase 03
- Session cleanup runs on create (sufficient for MVP); consider periodic cleanup if login rate exceeds 100/sec in production

## 2026-03-06 (iOS Dynamic Form Engine — Local Edit + Schema Rules Slice)

### Added

- **Client-side schema rule evaluator** for the existing `Condition` contract emitted by the backend; detail rendering now honors field-level `invisible` rules against current record or draft values
- **Local draft edit mode** on record detail with an `Edit` / `Cancel` affordance and in-memory draft state only; no backend writes or save actions introduced yet
- **Editable controls for the minimum useful subset**: `char`, `text`, `boolean`, and `selection`
- **Focused regression coverage** for condition evaluation, expanded field rendering, unsupported edit-mode fallback, and a UI path that enters detail edit mode while verifying visibility rules

### Changed

- `SchemaRendererView` now collapses invisible fields and hides empty sections/tabs instead of rendering hollow containers
- Fields marked `readonly: true` remain display-only even while the screen is in local edit mode
- Read-only detail rendering now supports **`priority`** and **`monetary`** as first-class field types instead of unsupported fallback rows
- UI smoke fixtures now include visibility-rule, readonly, monetary, priority, and draft-edit scenarios for the detail screen

### Fixed

- **MEDIUM (2026-03-06 customer detail hardening)**: customer detail screens no longer fail schema decoding when an Odoo instance exposes unsupported/custom field types inside the form view; backend now normalizes unknown field types to safe mobile fallbacks and iOS defensively decodes unexpected types as `.unsupported`
- **LOW (2026-03-06 customer detail polish)**: unsupported dynamic fields now render a generic "Unsupported field" hint instead of the awkward `unsupported` raw enum value

### Notes

- This slice implements **conditional visibility** and **static readonly** only. The current backend schema contract does not yet expose conditional readonly expressions, so iOS does not invent one.
- Edit mode is intentionally draft-only for now: no validation gate, no save CTA, no persistence, no backend write endpoint.

### Verified

- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — unit tests pass, including the new `ConditionEvaluatorTests` and expanded `FieldRowFactoryTests`
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoUITests/testSmokeLoginBrowseAndDetail -only-testing:OrdoUITests/testSmokeRestoresSessionAfterRelaunch -only-testing:OrdoUITests/testDetailEditModeShowsEditorsAndHonorsVisibilityRules test` — targeted UI tests pass
- `npm test --workspace backend -- --runInBand mobile-schema-builder.service.spec.ts && npm run lint --workspace backend` — backend schema builder tests and TypeScript lint pass after field-type normalization
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests/SchemaModelsTests -only-testing:OrdoTests/FieldRowFactoryTests test` — focused iOS tests for unknown-type decoding and unsupported-field fallback pass

## 2026-03-06 (iOS Dynamic Form Engine — Read-only Foundation)

### Added

- **Typed tab-section decoding** for schema-driven detail rendering; `FormTab.content.sections` now decodes into real `[FormSection]` values instead of remaining opaque JSON
- **Reusable read-only schema renderer** for record detail screens, covering both top-level sections and tab-backed sections from the backend schema contract
- **Field row factory + fallback rendering** for the first supported dynamic-form subset (`char`, `text`, `integer`, `float`, `boolean`, `selection`, `date`, `datetime`, `many2one`, `statusbar`) with graceful unsupported-type rows
- **Focused unit coverage** for schema tab decoding and read-only field row behavior
- **Smoke assertion for tab-backed content** in UI tests; the detail flow now verifies a rendered `comment` field coming from a schema tab section

### Changed

- `RecordDetailView` no longer hand-renders schema rows inline; it now delegates read-only composition to extracted renderer views
- `MobileFormSchema.requestedFieldNames` now includes field names from decoded tab sections so record fetches request the full visible detail payload
- UI-test schema fixtures now include a `Notes` tab with a `comment` field to exercise the new renderer path end-to-end

### Fixed

- **HIGH (2026-03-06 live iOS verification)**: notebook/tab fields were effectively stranded in opaque tab content and did not render on the detail screen
- **MEDIUM (2026-03-06 dynamic-form verification)**: auth envelope decoding regressed when optional string fields arrived as boolean `false`; defensive lossy decoding keeps login/session restore stable during renderer verification

### Verified

- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — unit tests pass, including schema tab decoding, field-row factory, cache TTL, and auth decoding regression coverage
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoUITests/testSmokeLoginBrowseAndDetail -only-testing:OrdoUITests/testSmokeRestoresSessionAfterRelaunch test` — targeted smoke tests pass end to end

## 2026-03-06 (iOS Hardening — Cache & Pagination & Deterministic Tests)

### Added

- **Cache write failure logging** with OSLog when FileCacheStore fails to persist schema/record/list pages; errors logged but non-blocking
- **Session-scoped cache isolation** via `CacheScope` struct; each session (odooUrl + db + uid) maintains isolated cache namespace preventing data leakage between users on same device
- **Cache key collision prevention** using SHA256 hashing of model names instead of character sanitization
- **Pagination offset hardening** via `loadedOffsets` Set to prevent duplicate page fetches and `nextOffset` tracking for next-page boundary detection
- **Deduplication on merge** in record list view-model; incoming records checked against existing `seenIDs` before appending to prevent ID collisions across paginated fetches
- **Cache TTL eviction** with fine-grained lifetimes: 7-day TTL for schema, 24-hour TTL for record details and list pages; expired entries logged and removed on load attempt
- **Deterministic UI smoke tests** with `UITestURLProtocol` intercepting all network requests and `UITestAppStateFactory` providing in-process fixtures when `ORDO_UI_TEST_MODE=smoke`
  - Fixture endpoints return hardcoded auth tokens, principals, schemas, records, and search results
  - Pagination offset query param parsed deterministically (e.g., `offset=0` returns full fixture list, non-zero offsets return empty for stateless testing)
  - All cache/session storage scoped to UI test suite via UserDefaults and ephemeral cache directories
- **Auth response decode hardening** via lossy optional-string decoding for `AuthUser` and `AuthenticatedPrincipal`; falsy upstream values like `false`, `null`, or blank strings now normalize to `nil` instead of failing login/session restore decoding
- **xcodebuild + test suite verification**: full build succeeds (0 errors); OrdoTests unit target passes; OrdoUITests smoke suite validates login → browse → detail and session restore flows

### Changed

- FileCacheStore now wraps all file I/O with try/catch; save failures logged via OSLog but do not propagate or block list rendering
- Record list pagination now deduplicates incoming records before merging, protecting against server-side pagination anomalies or offset edge cases
- Cache store methods now require `scope: CacheScope` parameter for session-aware isolation

### Fixed

- **CRITICAL (2026-03-06 code review)**: Cache data leakage between users — resolved via session-scoped namespace isolation
- **CRITICAL (2026-03-06 code review)**: Cache key collision potential — resolved via SHA256 hashing
- **HIGH (2026-03-06 code review)**: Silent cache write failures — resolved via OSLog error capture
- **HIGH (2026-03-06 code review)**: Pagination offset tracking edge cases — resolved via deduplication on merge
- **HIGH (2026-03-06 code review)**: No cache expiration policy — resolved via tiered TTL with auto-cleanup
- **HIGH (2026-03-06 live auth validation)**: iOS login/session restore decode failures when Odoo-backed auth payloads leaked boolean `false` for optional string fields such as `email` and `tz`

### Verified

- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` — build succeeds (0 errors)
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoTests test` — unit tests pass (all cache/TTL tests)
- `xcodebuild -project Ordo.xcodeproj -scheme Ordo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing:OrdoUITests test` — smoke tests pass (2/2: login→browse→detail, session restore)

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