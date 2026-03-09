---
description: "Use when editing Ordo backend or shared transport files, including NestJS modules, DTOs, controllers, services, Odoo adapters, tests, and API contracts. Covers contract reuse, module boundaries, validation, and regression expectations."
name: "Ordo Backend Workflow"
applyTo: "backend/src/**/*.ts, backend/test/**/*.ts, shared/src/**/*.ts"
---
# Ordo Backend Workflow

- Start from `README.md`, `docs/system-architecture.md`, and the live shared contracts before changing request or response shapes.
- Treat `shared/` as the transport source of truth; reuse `@ordo/shared` instead of redefining payload types in `backend/`.
- Keep reusable HTTP concerns under `backend/src/common/` and keep feature logic inside the owning module.
- Preserve the existing response envelope and route semantics unless the task explicitly changes the public contract.
- Scope changes tightly: backend-only slices should stay inside `backend/` unless a contract change truly requires `shared/` edits.
- For adapter work, keep Odoo-version behavior behind the adapter layer instead of leaking version checks into controllers or feature services.
- Run package-appropriate validation: backend-only changes should use `npm run build --workspace backend` and `npm run test --workspace backend`; `shared/` changes should use root `npm run build` and `npm test` because they affect multiple packages.
- Add focused regressions for the surface you changed, especially auth, schema, records, chatter, actions, or onchange flows.
