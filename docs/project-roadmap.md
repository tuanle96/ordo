# Project Roadmap

## Phase status

| Phase | Status | Notes |
| --- | --- | --- |
| Handoff 1 — Foundation | Complete | Docs baseline, npm workspace, shared contracts, Nest bootstrap, health smoke test |
| Handoff 2 — Odoo auth and RPC | Complete | Auth module, JWT, version detection, JSON-RPC client, protected `/auth/me`, and live login validation against Odoo 17/18/19 |
| Handoff 3 — Schema and records | Complete | Session bridge, `GET /schema/:model`, `GET /records/:model`, `GET /records/:model/:id`, `GET /search/:model`, plus live happy-path validation against Odoo 17/18/19 |
| Handoff 4 — Dashboard and hardening | Complete | Real backend test harness and regression suite; docs/status cleanup; live multi-Odoo version validation |
| Handoff 5 — iOS native MVP | Complete | Native SwiftUI foundation, auth/login, session restore, API client, file-based offline cache with TTL eviction, res.partner pagination/load-more with offset hardening and deduplication, settings with cache clear, deterministic UI smoke tests with mocked transport; xcodebuild build verified; OrdoTests + OrdoUITests passing |
| Handoff 6 — Backend forms & mutations (Phase 01/02) | Complete | Auth refresh with session touch lifecycle; backend record mutations (create/update/delete/action) with canonical post-write reads; shared contracts + comprehensive test coverage |
| Handoff 6 — iOS save flow & validation (Phase 03) | Complete | Refresh-aware auth retry; save/discard UX with confirmation; dirty tracking and required-field validation; fixture-backed PATCH flow; new unit/UI tests (16/16 passing, xcodebuild verified) |
| Handoff 6 — Relation editors & model expansion (Phase 04) | Complete | `many2one` search/select/clear editor shipped; relation payload normalization added; `crm.lead` and narrow `sale.order` browse/detail support added; nested relation editors remain deferred |
| Handoff 6 — Testing hardening & docs (Phase 05) | Complete | Save-failure path hardened to preserve drafts inline; discard-confirmation and relation-clear regressions covered; repo build/tests and iOS validations rerun; stale Handoff 4 plan status corrected |
| Phase 2 — Production hardening (Phase 01) | ✅ Complete | Redis-backed Odoo session store landed with shared Redis provider, validated backend build/test pass, and multi-instance-safe session persistence foundation |
| Phase 2 — Production hardening (Phase 02) | ✅ Complete | Redis-backed `GET /schema/:model` cache landed with conservative tenant/user/lang/version/model keys, 1h TTL, and fail-open fallback when Redis is unavailable |
| Phase 2 — Production hardening (Phase 03) | ✅ Complete | Auth perimeter now has route-scoped throttling for `login`/`refresh` plus explicit env-driven CORS allowlisting with fail-closed preflight behavior |
| Phase 2 — Production hardening (Phase 04) | ✅ Complete | Pino-based structured logging landed with central redaction, request IDs, JSON app logs outside test mode, and deterministic Jest output |
| Phase 2 — Production hardening (Phase 05) | ✅ Complete | iOS unit coverage broadened around refresh, cache fallback, browse/detail state, and recents persistence; three Swift Testing suites now run serialized and green, establishing the baseline that Phase 06A/06B later used to close the relaunch seam |
| Phase 2 — Next iOS slice (Phase 06A) | ✅ Complete | Recent-items relaunch determinism seam isolated and verified with the targeted relaunch UI test green before observation changes landed |
| Phase 2 — Next iOS slice (Phase 06B) | ✅ Complete | `RecentItemsStore` migrated to `@Observable`; `OrdoApp` root ownership plus `HomeView` and `RecordDetailView` consumer patterns validated with green unit and targeted UI coverage |
| Phase 07 — iOS form editors & list browsing improvements | ✅ Complete | Many2many editable tags shipped and browse table mode + sort landed in the original slice; chatter later expanded in follow-up slices to cover thread read, post-note, follower self-follow/unfollow, activity scheduling, and activity completion with lazy-load UI + adapter delegation |
| Phase 08 — iOS create flow & primitive editor expansion | ✅ Complete | Record detail now supports create-mode navigation from browse lists plus editable `integer`, `float`, `date`, and `datetime` fields backed by draft normalization, validation, and canonical POST readback; deterministic create-flow UI/E2E coverage remains an explicit follow-up hardening gap |
| Phase 09 — Odoo onchange foundation | ✅ Complete | Shared contracts, backend transport, iOS debounce/merge/warnings, backend fail-closed hardening, and live Odoo 17 `res.partner` validation are complete; broad returned-domain application and deeper x2many parity remain deferred |
| Phase 10 — iOS workflow action buttons | ✅ Complete | Record detail now renders visible schema header actions for persisted read-mode records, supports confirm dialogs plus single-flight execution, updates cached record state after action completion, and ships focused unit validation plus mutable UI-test fixtures; broader simulator UI stabilization remains a follow-up hardening concern rather than a blocker for the shipped slice |
| Phase 11 — Explicit auth logout | ✅ Complete | Guarded `POST /auth/logout` now revokes the Redis-backed `sessionHandle`, best-effort destroys the upstream Odoo session cookie bridge, and powers a remote-first Settings sign-out flow with focused backend + iOS regression coverage |
| Core-first platform — Phase 01 generic form engine | ✅ Complete | The minimum reusable field matrix is now closed across iOS read/edit/validation paths, including `html`, `monetary`, narrow `one2many`, relation payload normalization, and the last read-only renderer gaps |
| Core-first platform — Phase 01 closeout foundations | ✅ Complete | Create mode now hydrates Odoo defaults through a narrow `GET /records/:model/defaults` route, persisted records support safe delete parity on iOS, and `priority` ships as a generic star editor with focused backend + iOS validation |
| Core-first platform — Phase 02A image-first media widget | ✅ Complete | Record detail now supports read-only image preview plus edit-mode choose/replace/clear with inline size validation and focused iOS regression coverage; broader `binary`, `signature`, and statusbar tap-to-change remain deferred |
| Core-first platform — Phase 02B binary/document upload MVP | ✅ Complete | Record detail now supports generic `binary` fields for small documents (≤1.5 MB) through `UIDocumentPicker`, with honest filename persistence when schema declares a companion field; broader attachment endpoints, offline queue, and preview/download flows remain deferred |
| Core-first platform — Phase 02D signature capture + inline preview/export | ✅ Complete | Record detail now supports `signature` draw/replace/clear via a narrow `PencilKit` capture surface, bounded read-only preview, and local Preview / Export actions for already-loaded `binary` and `signature` payloads without introducing backend download routes |
| Core-first platform — Phase 02C statusbar tap-to-change | ✅ Complete | Record detail now supports a narrow action-backed statusbar tap affordance for binary selection flows with exactly one visible workflow action, while unsupported many2one/multi-action statusbars remain read-only |

## Scope reminders

- Source-of-truth stack is SwiftUI + NestJS
- Target Odoo compatibility starts with 17, 18, and 19
- iOS implementation starts after backend MVP core stabilizes