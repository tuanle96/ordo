# Project Overview

## Product

Ordo is a mobile-first client for Odoo Community focused on fast operational workflows for field teams and managers.

## Implementation direction

- iOS client: SwiftUI
- Middleware/backend: NestJS
- Shared contracts: TypeScript package in `shared/`
- Reference Odoo versions: 17, 18, 19

## Current delivered platform

The backend-first rollout is no longer at the "early handoff" stage. The current shipped platform now includes:

- Odoo auth, refresh, logout, and Redis-backed upstream session persistence
- schema-driven form and list contracts, including `GET /schema/:model/list`
- record browse/detail/search plus create/update/delete/action mutation routes
- backend onchange transport and menu/action-backed dynamic browse discovery
- native iOS browse/detail/edit/create/delete flows
- chatter thread read/post and narrow follower/activity workflows
- local cache plus file-backed offline mutation queue management UX
- inline local preview/export for already-loaded image, binary, and signature payloads

## Current product boundaries

The platform is usable and broadly shipped, but several areas remain intentionally narrow or deferred:

- browse grouping is client-side only on top of flat list payloads
- statusbar interaction is shipped only for narrow action-backed two-state selection flows; many2one stage flows such as `crm.lead.stage_id` remain read-only
- attachment preview/export is local-only for bytes already returned in record detail; there is no backend file proxy or large-file download path yet
- offline support covers cache plus queued update/delete/action replay, not full sync/conflict/background behavior
- dynamic list schema already carries `SearchField.filterDomain`, but iOS does not yet apply that metadata when building browse filters
- read-only relation labels still do not drill into related record detail
- multi-company switching is still not implemented

## Delivery history summary

The incremental handoff history remains useful for chronology, but these are the current high-level milestones rather than active work-in-progress labels:

- Foundation, auth, schema, and record surfaces are complete
- Native iOS browse/detail/edit foundations are complete
- production-hardening foundations such as Redis sessions/cache, auth perimeter hardening, and structured logging are complete
- core form-engine/media/statusbar/offline queue slices are complete for their intended narrow scope
- dynamic browse discovery now comes from backend menu/action exposure rather than a hardcoded local allowlist

See these docs for the live detail level:

- `docs/project-roadmap.md` — cumulative shipped status by phase
- `docs/project-changelog.md` — chronological slice history
- `docs/system-architecture.md` — exact current architecture and narrow boundaries

## Explicit correction

Any stale references to Flutter or FastAPI in older planning text are superseded by the architecture and tech-stack decisions in `prd.md` and the current repo docs.