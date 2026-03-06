# Project Roadmap

## Phase status

| Phase | Status | Notes |
| --- | --- | --- |
| Handoff 1 — Foundation | Complete | Docs baseline, npm workspace, shared contracts, Nest bootstrap, health smoke test |
| Handoff 2 — Odoo auth and RPC | Complete | Auth module, JWT, version detection, JSON-RPC client, protected `/auth/me`, and live login validation against Odoo 17/18/19 |
| Handoff 3 — Schema and records | Complete | Session bridge, `GET /schema/:model`, `GET /records/:model`, `GET /records/:model/:id`, `GET /search/:model`, plus live happy-path validation against Odoo 17/18/19 |
| Handoff 4 — Dashboard and hardening | In Progress | Real backend test harness and regression suite are in place; docs/status cleanup is underway; dashboard remains optional and deferred unless it stays tiny |

## Scope reminders

- Source-of-truth stack is SwiftUI + NestJS
- Target Odoo compatibility starts with 17, 18, and 19
- iOS implementation starts after backend MVP core stabilizes