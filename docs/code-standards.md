# Code Standards

## General rules

- Prefer YAGNI, KISS, and DRY
- Use kebab-case for file names
- Keep files focused and small
- Avoid introducing framework complexity before it is needed

## TypeScript

- Use TypeScript 5.x
- Export explicit interfaces and types for transport contracts
- Prefer readonly where it improves intent
- Keep DTO and contract naming aligned with API language

## NestJS

- Keep modules self-contained
- Put reusable HTTP concerns under `backend/src/common/`
- Use consistent response envelopes for all public endpoints
- Prefer seams and interfaces before real Odoo business logic

## Shared contracts

- `shared/` is the source of truth for auth, schema, record, and API envelope contracts
- Backend must import contracts instead of redefining them locally

## Documentation

- Update roadmap and changelog when a handoff completes
- Record stack decisions when they override stale planning text