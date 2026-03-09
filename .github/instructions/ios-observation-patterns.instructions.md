---
description: "Use when editing Ordo iOS app, tests, or SwiftUI state code. Covers the current Swift Observation pattern, typed environment injection, authenticated networking, and request-intercept test expectations."
name: "Ordo iOS Observation Patterns"
applyTo: "ios/Ordo/**/*.swift, ios/OrdoTests/**/*.swift, ios/OrdoUITests/**/*.swift"
---
# Ordo iOS Observation Patterns

- Treat `README.md`, `ios/Ordo/OrdoApp.swift`, and `ios/Ordo/app/app-state.swift` as the authority for current app-state patterns.
- Prefer `@MainActor @Observable` for app state, stores, and state-heavy view models.
- Own app-level observable dependencies with `@State` in `OrdoApp`, then inject them with typed `.environment(...)`.
- Consume shared app-level dependencies with `@Environment(Type.self)`; do not reintroduce legacy `@EnvironmentObject` / `@StateObject` patterns for these stores.
- Route authenticated backend work through `AppState.withAuthenticatedToken()` and preserve the existing unauthorized-to-sign-out behavior.
- Keep feature code self-contained under `ios/Ordo/features/` and avoid pushing view-specific logic into global app state without a clear cross-feature need.
- Validate iOS changes with `xcodebuild`, preferring targeted `-only-testing:` suites before broader runs.
- In request-intercept tests using custom `URLProtocol`, handle `httpBodyStream` as well as `httpBody` when asserting POST payloads.
