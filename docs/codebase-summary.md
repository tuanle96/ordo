# Codebase Summary

## Current state

Ordo is now a real backend + native iOS product slice, not just a foundation scaffold.

The repository currently contains:

- `prd.md` as the main product specification
- `.claude/` workflow and skill configuration
- `backend/` NestJS middleware normalizing Odoo 17/18/19 behind one mobile API
- `shared/` transport contracts used as the backend source of truth
- `ios/` native SwiftUI app with schema-driven browse/detail/edit flows
- `docs/` living status, architecture, roadmap, and contributor guidance
- `odoo-instances/` local Docker validation stack for Odoo 17/18/19
- `odoo-src/` vendored Odoo source for reference only

## Current backend surface

The backend now ships and verifies:

- auth via `POST /auth/login`, `GET /auth/me`, `POST /auth/refresh`, and `POST /auth/logout`
- Redis-backed upstream Odoo session persistence plus Redis-backed schema caching
- version-aware Odoo integration for 17, 18, and 19 through adapter seams
- schema-driven reads via `GET /schema/:model` and `GET /schema/:model/list`
- record list/detail/search plus create/update/delete/action mutation routes
- backend-driven onchange transport for mobile forms
- dynamic module discovery plus menu/action-backed `browseMenuTree` discovery
- structured backend logging, auth throttling, explicit CORS, and automated Jest + Supertest regressions

## Current iOS surface

The iOS app now ships with:

- session restore, refresh-aware authenticated requests, and explicit logout
- dynamic Browse/Home navigation from backend discovery tree instead of a hardcoded browse allowlist
- schema-driven list browsing with table/cards, sort, quick filters, persisted filter state, and client-side grouped sections
- schema-driven record detail with read, edit, create, delete, workflow actions, and narrow statusbar tap-to-change
- generic form-engine coverage for the shipped field matrix, including relation editors, monetary, HTML, image, binary, signature, priority, and narrow `one2many`
- chatter thread read/post plus follower/activity scheduling/completion slices
- local file cache for schema/record/list data and a file-backed offline mutation queue with inspect/retry/remove/clear controls in Settings
- inline local preview/export for already-loaded image, binary, and signature payloads

## Current honest boundaries

The product is far beyond MVP scaffolding, but a few areas are still intentionally narrow or deferred:

- browse grouping is client-side only; there is no backend aggregate/group-count response yet
- statusbar interaction is only shipped for narrow two-state, action-backed selection flows; many2one stage flows such as CRM stages remain non-interactive
- inline attachment preview/export works for already-loaded payload bytes, but there is still no backend download/proxy or large-file fetch path
- offline support includes cache plus queued update/delete/action replay, not a full sync/conflict/background engine
- `SearchField.filterDomain` metadata exists in list schema, but iOS does not yet apply it when building dynamic browse filters
- relation drilldown from read-only many2one/many2many labels into related record detail is still missing
- multi-company switching is still not implemented

## Package ownership

- `shared/` owns transport-level contracts
- `backend/` owns API runtime, Odoo integration logic, auth/session policy, and contract-backed schema/list/record behavior
- `ios/` owns the native SwiftUI client, app state, browse/detail/form UX, and local cache/offline queue behavior
- `odoo-instances/` owns local integration infrastructure for Postgres + Odoo 17/18/19
- `odoo-src/` is reference material only and should not receive product changes