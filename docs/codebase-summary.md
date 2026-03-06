# Codebase Summary

## Current state

The repository currently contains:

- `prd.md` as the main product specification
- `.claude/` workflow and skill configuration
- `odoo-src/` with vendored Odoo source for versions 17, 18, and 19

The repository did not originally contain:

- `backend/`
- `shared/`
- root `README.md`
- root `docs/`

## Purpose of the scaffold

The scaffold introduced in Handoff 1 creates a clean starting point for backend-first delivery without committing to full feature implementation too early.

## Package ownership

- `shared/` owns transport-level contracts
- `backend/` owns API runtime and Odoo integration logic
- `odoo-src/` is reference material only