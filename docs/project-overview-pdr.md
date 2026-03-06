# Project Overview

## Product

Ordo is a mobile-first client for Odoo Community focused on fast operational workflows for field teams and managers.

## Implementation direction

- iOS client: SwiftUI
- Middleware/backend: NestJS
- Shared contracts: TypeScript package in `shared/`
- Reference Odoo versions: 17, 18, 19

## Current delivery strategy

The repository is executing a backend-first rollout with incremental handoffs.

Handoff 1 (complete):
- repository foundation docs
- Node workspace setup
- shared contracts
- NestJS bootstrap

Handoff 2 (implemented, pending live validation):
- Auth module with Odoo login and token issuance
- JSON-RPC transport for version-aware Odoo integration
- First protected endpoint (`GET /auth/me`)

Handoff 3+ planned:
- Schema parsing and record CRUD
- Dashboard and search APIs
- Comprehensive test coverage and hardening

## Explicit correction

Any stale references to Flutter or FastAPI in older planning text are superseded by the architecture and tech-stack decisions in `prd.md`.