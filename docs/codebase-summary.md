# Codebase Summary

## Current state

The repository currently contains:

- `prd.md` as the main product specification
- `.claude/` workflow and skill configuration
- `odoo-src/` with vendored Odoo source for versions 17, 18, and 19
- `backend/`
- `shared/`
- root `README.md`
- root `docs/`
- `odoo-instances/` for local Odoo 17/18/19 Docker validation

## Current backend surface

The backend now ships and verifies:

- auth via `POST /auth/login` and `GET /auth/me`
- version-aware Odoo integration for 17, 18, and 19
- session-backed reads for schema, records, and relation search
- automated backend regression tests with Jest + Supertest
- live local validation through the Dockerized `odoo-instances/` stack

## Package ownership

- `shared/` owns transport-level contracts
- `backend/` owns API runtime and Odoo integration logic
- `odoo-instances/` owns local integration infrastructure for Postgres + Odoo 17/18/19
- `odoo-src/` is reference material only