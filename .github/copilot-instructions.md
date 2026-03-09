# Ordo Workspace Instructions

## Start Here

- Read `README.md` first for the current product, architecture, and verified commands.
- Use `docs/code-standards.md` for coding conventions and `docs/system-architecture.md` for module boundaries.
- When a feature or bug-fix changes project status, update `docs/project-roadmap.md` and `docs/project-changelog.md`.

## Architecture

- `shared/` is the transport-contract source of truth. Reuse shared types instead of redefining API payloads in `backend/`.
- `backend/` is a NestJS middleware layer that normalizes Odoo 17/18/19 behind version adapters and exposes the mobile API.
- `ios/` is a native SwiftUI client that talks to the backend API, not directly to Odoo.
- Keep changes scoped to the owning package unless a contract change requires coordinated updates across `shared/`, `backend/`, and `ios/`.

## Build and Test

- Install dependencies from the repo root with `npm install`.
- Root validation commands:
  - `npm run build` — builds `shared` and `backend`
  - `npm test` — runs `shared` checks and backend tests
  - `npm run lint` — type-check style validation for `shared` and `backend`
- Backend-only commands live in `backend/package.json`:
  - `npm run build --workspace backend`
  - `npm run test --workspace backend`
  - `npm run start:dev --workspace backend`
- iOS validation is separate from the npm workspace. Use Xcode or `xcodebuild -project ios/Ordo.xcodeproj -scheme Ordo -destination 'generic/platform=iOS Simulator' build` for builds, and prefer targeted `-only-testing:` runs for affected suites before broader coverage.

## Conventions

- Prefer YAGNI, KISS, and DRY.
- Use kebab-case file names.
- Keep files focused and small; extract helpers/services instead of growing large mixed-responsibility files.
- Preserve the existing public API and response envelope patterns unless the task explicitly changes them.
- For backend work, keep reusable HTTP concerns under `backend/src/common/` and feature logic inside its owning module.
- For iOS work, follow the current Swift Observation pattern used in `ios/Ordo/OrdoApp.swift`: root-owned `@State`, `@Observable` stores, and typed `.environment(...)` injection.

## Practical Pitfalls

- The root npm scripts do not build or test the iOS app; validate iOS changes separately with `xcodebuild`.
- Some older docs still mention legacy SwiftUI observation patterns. Treat `README.md` and the live code in `ios/Ordo/OrdoApp.swift` as authoritative for current app-state injection.
- `odoo-src/` is vendored reference material, not the place for product code changes.
- Prefer narrow, targeted tests first when working in large surfaces like chatter, onchange, or iOS state flows, then broaden validation as needed.

## Useful References

- `README.md`
- `docs/code-standards.md`
- `docs/system-architecture.md`
- `docs/codebase-summary.md`
- `docs/project-roadmap.md`
- `docs/project-changelog.md`