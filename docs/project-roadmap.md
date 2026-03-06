# Project Roadmap

## Phase status

| Phase | Status | Notes |
| --- | --- | --- |
| Handoff 1 — Foundation | Complete | Docs baseline, npm workspace, shared contracts, Nest bootstrap, health smoke test |
| Handoff 2 — Odoo auth and RPC | In Progress | Auth module, JWT, version detection, JSON-RPC client, protected `/auth/me` with offline smoke tests; live Odoo integration pending |
| Handoff 3 — Schema and records | In Progress | Session bridge, `GET /schema/:model`, `GET /records/:model`, `GET /records/:model/:id`, `GET /search/:model`; live Odoo happy-path validation pending |
| Handoff 4 — Dashboard and hardening | Planned | Dashboard read APIs, tests, docs cleanup |

## Scope reminders

- Source-of-truth stack is SwiftUI + NestJS
- Target Odoo compatibility starts with 17, 18, and 19
- iOS implementation starts after backend MVP core stabilizes