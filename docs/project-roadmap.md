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
| Phase 2 — Production hardening (Phase 01) | In Progress | Redis-backed Odoo session store landed with shared Redis provider, validated backend build/test pass, and multi-instance-safe session persistence foundation |
| Phase 2 — Production hardening (Phase 02) | In Progress | Redis-backed `GET /schema/:model` cache landed with conservative tenant/user/lang/version/model keys, 1h TTL, and fail-open fallback when Redis is unavailable |
| Phase 2 — Production hardening (Phase 03) | In Progress | Auth perimeter now has route-scoped throttling for `login`/`refresh` plus explicit env-driven CORS allowlisting with fail-closed preflight behavior |
| Phase 2 — Production hardening (Phase 04) | In Progress | Pino-based structured logging landed with central redaction, request IDs, JSON app logs outside test mode, and deterministic Jest output |
| Phase 2 — Production hardening (Phase 05) | ✅ Complete | iOS unit coverage broadened around refresh, cache fallback, browse/detail state, and recents persistence; three Swift Testing suites now run serialized and green, establishing the baseline that Phase 06A/06B later used to close the relaunch seam |
| Phase 2 — Next iOS slice (Phase 06A) | ✅ Complete | Recent-items relaunch determinism seam isolated and verified with the targeted relaunch UI test green before observation changes landed |
| Phase 2 — Next iOS slice (Phase 06B) | ✅ Complete | `RecentItemsStore` migrated to `@Observable`; `OrdoApp` root ownership plus `HomeView` and `RecordDetailView` consumer patterns validated with green unit and targeted UI coverage |
| Phase 07 — iOS form editors & list browsing improvements | ✅ Complete | Many2many editable tags shipped; browse table mode + sort landed; chatter now supports thread read, post-note, follower self-follow/unfollow, and activity completion with lazy-load UI + adapter delegation |
| Phase 08 — iOS create flow & primitive editor expansion | In Progress | Record detail now supports create-mode navigation from browse lists plus editable `integer`, `float`, `date`, and `datetime` fields backed by draft normalization, validation, and canonical POST readback; deterministic create-flow UI/E2E coverage remains pending |
| Phase 09 — Odoo onchange foundation | In Progress | Shared onchange contracts and backend transport are in place; iOS Phase 03 now ships debounced onchange requests, safe draft merges, inline warnings, and green unit validation; Phase 04 rollout hardening remains pending |

## Scope reminders

- Source-of-truth stack is SwiftUI + NestJS
- Target Odoo compatibility starts with 17, 18, and 19
- iOS implementation starts after backend MVP core stabilizes