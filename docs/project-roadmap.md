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

## Scope reminders

- Source-of-truth stack is SwiftUI + NestJS
- Target Odoo compatibility starts with 17, 18, and 19
- iOS implementation starts after backend MVP core stabilizes