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

## Swift / SwiftUI

- Use Swift 5.x with SwiftUI as the primary UI framework
- File naming: kebab-case (e.g., `api-client.swift`, `app-state.swift`)
- Leverage `@MainActor` for thread-safe state management
- Use `@StateObject` and `@EnvironmentObject` for app-wide dependencies
- Prefer async/await over completion handlers
- Keep feature screens self-contained in `features/` subdirectories
- App bootstrap through `AppState.live()` factory for dependency injection

## Shared contracts

- `shared/` is the source of truth for auth, schema, record, and API envelope contracts
- Backend must import contracts instead of redefining them locally
- iOS must use shared TypeScript contract types via generated or manually maintained mappings

## Documentation

- Update roadmap and changelog when a handoff completes
- Record stack decisions when they override stale planning text
- Maintain architecture and surface documentation for new handoffs