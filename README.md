<p align="center">
  <img src="docs/assets/ordo-banner.png" alt="Ordo — Mobile-first client for Odoo Community Edition" width="800" />
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## Overview

Odoo Community has no official mobile app. **Ordo** fills this gap with a schema-driven, offline-capable native iOS client that connects to any Odoo server (v17–v19) through a lightweight NestJS middleware.

The middleware handles version differences, authentication, and schema introspection — so the mobile app receives a **consistent API** regardless of the Odoo version running on the server.

### Key Differentiators

- 🔌 **Multi-tenant** — One backend serves N Odoo servers. Users can connect to any Odoo instance.
- 🧩 **Schema-driven forms** — Middleware introspects Odoo's `ir.model.fields` + `ir.ui.view` XML and generates mobile-optimized JSON schemas.
- 🔄 **Version adapters** — Abstracts Odoo API differences (v17/v18/v19) behind a unified interface.
- 🌐 **Dynamic i18n** — App language follows the user's Odoo `context.lang` setting.
- 📶 **Offline-capable** — File-based cache with graceful degradation when network is unavailable.

---

## Features

### ✅ Implemented

| Area                     | Backend                                                     | iOS                                                       |
| ------------------------ | ----------------------------------------------------------- | --------------------------------------------------------- |
| **Authentication**       | `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`, JWT with session bridge | Login screen, Keychain persistence, session restore       |
| **Version Detection**    | Auto-detect Odoo 17/18/19 via `/web/webclient/version_info` | —                                                         |
| **Schema Introspection** | `GET /schema/:model` — XML arch → mobile JSON schema        | —                                                         |
| **Record Browsing**      | `GET /records/:model`, `GET /records/:model/:id`            | Paginated list, detail view, pull-to-refresh for `res.partner`, `crm.lead`, and narrow `sale.order` |
| **Search**               | `GET /search/:model` (name_search)                          | Debounced search with 300ms delay, plus relation search for supported `many2one` editors |
| **Record Write**         | `POST /records/:model` (create), `PATCH /records/:model/:id` (update), `DELETE /records/:model/:id` (delete), `POST /records/:model/:id/actions/:name` (action) | Edit mode for `char`, `text`, `boolean`, `selection`, `many2one`; save/discard UX; dirty tracking; required-field validation; refresh-aware auth retry across `res.partner` with fixture-backed coverage for `crm.lead` and narrow `sale.order` |
| **Offline Cache**        | —                                                           | File-based cache with actor isolation, stale-data banners |
| **Health Check**         | `GET /health` (unprefixed)                                  | —                                                         |

### 🚧 Planned

Broader nested relation editors (`one2many`, `many2many`), deeper field type coverage, biometric auth, push notifications, WebSocket real-time updates, barcode scanner, multi-server switcher, and more. See [Roadmap](#roadmap).

---

## Architecture

```
┌─────────────────────────────────────────────┐
│          iOS App (Swift / SwiftUI)           │
│  AppState · APIClient · Keychain · Cache    │
└──────────────────┬──────────────────────────┘
                   │ HTTPS (REST + JWT)
┌──────────────────┴──────────────────────────┐
│     NestJS Middleware (TypeScript)           │
│  Auth · Schema Builder · Record Service     │
│  Version Adapters (v17/v18/v19)             │
│  Session Store · Transform Interceptor      │
└────────┬───────────────┬───────────┬────────┘
         │               │           │ JSON-RPC
    ┌────┴────┐    ┌─────┴────┐  ┌───┴──────┐
    │ Odoo 17 │    │ Odoo 18  │  │ Odoo 19  │
    └─────────┘    └──────────┘  └──────────┘
```

### Tech Stack

| Layer            | Technology                              |
| ---------------- | --------------------------------------- |
| iOS UI           | SwiftUI (iOS 17+)                       |
| iOS Architecture | MVVM + `ObservableObject`               |
| iOS Networking   | URLSession + async/await + Codable      |
| iOS Storage      | Keychain Services + file-based cache    |
| Backend          | NestJS 11 + TypeScript 5.x              |
| Runtime          | Node.js 22 LTS                          |
| Auth             | `@nestjs/jwt` + `@nestjs/passport`      |
| Redis Store      | `ioredis` (sessions + schema cache) |
| Odoo RPC         | Custom JSON-RPC client (fetch-based)    |
| Validation       | `class-validator` + `class-transformer` |
| Shared Types     | TypeScript package (`@ordo/shared`)     |
| Tests            | Jest + Supertest (E2E + unit)           |

---

## Getting Started

### Prerequisites

| Tool    | Version                              |
| ------- | ------------------------------------ |
| Node.js | 22 LTS                               |
| npm     | 10+                                  |
| Xcode   | 15+ (for iOS)                        |
| Docker  | Optional — for local Odoo validation |

### Installation

```bash
# Clone the repository
git clone https://github.com/tuanle96/ordo.git
cd ordo

# Install all dependencies (backend + shared)
npm install
```

### Environment Setup

```bash
# Copy the example env file
cp backend/.env.example backend/.env
```

Edit `backend/.env` with your values:

```env
JWT_ACCESS_SECRET=your-access-secret
JWT_REFRESH_SECRET=your-refresh-secret
JWT_ACCESS_EXPIRES_IN_SECONDS=900
JWT_REFRESH_EXPIRES_IN_SECONDS=604800
REDIS_URL=redis://127.0.0.1:6379
ODOO_REQUEST_TIMEOUT_MS=15000
ODOO_SESSION_TTL_SECONDS=1800
```

### Running

#### Backend

```bash
# Development mode (with hot reload)
npm run dev:backend

# Production build
npm run build
```

The API will be available at `http://localhost:3000/api/v1/mobile`.

#### iOS

Open `ios/Ordo.xcodeproj` in Xcode, select a simulator, and hit **Run** (⌘R).

Or build from command line:

```bash
xcodebuild -project ios/Ordo.xcodeproj \
  -scheme Ordo \
  -destination 'generic/platform=iOS Simulator' \
  build
```

#### Local Odoo Stack (Optional)

```bash
cd odoo-instances
docker compose up -d --build
```

This spins up Odoo 17, 18, and 19 instances for local validation.

### Running Tests

```bash
# Backend tests (Jest)
npm test

# With coverage
npm run test:coverage
```

### Health Check

```bash
curl http://localhost:3000/health
```

---

## Project Structure

```
Ordo/
├── backend/                  ← NestJS middleware
│   ├── src/
│   │   ├── modules/
│   │   │   ├── auth/         ← Login, JWT, guards
│   │   │   ├── health/       ← Health check endpoint
│   │   │   ├── record/       ← CRUD + search endpoints
│   │   │   └── schema/       ← Schema introspection endpoint
│   │   ├── odoo/
│   │   │   ├── adapters/     ← Version-specific adapters (v17/v18/v19)
│   │   │   ├── rpc/          ← JSON-RPC client
│   │   │   ├── schema/       ← XML arch → mobile JSON builder
│   │   │   └── session/      ← Upstream session store
│   │   ├── common/           ← Guards, interceptors, pipes, DTOs
│   │   ├── app.module.ts
│   │   └── main.ts
│   └── test/                 ← E2E + unit tests
│
├── ios/                      ← SwiftUI native app
│   └── Ordo/
│       ├── app/              ← AppState, config, tab view
│       ├── features/
│       │   ├── auth/         ← Login view
│       │   ├── browse/       ← Record list, model registry
│       │   ├── record-detail/← Record detail view
│       │   ├── settings/     ← Settings screen
│       │   └── home/         ← Home / dashboard placeholder
│       ├── networking/       ← API client
│       ├── persistence/      ← Keychain + file cache
│       └── shared/models/    ← Swift Codable models
│
├── shared/                   ← TypeScript type contracts
│   └── src/
│       ├── auth.types.ts
│       ├── schema.types.ts
│       ├── record.types.ts
│       └── api.types.ts
│
├── docs/                     ← Engineering documentation
├── plans/                    ← Implementation plans & reports
├── odoo-instances/           ← Docker Compose for local Odoo
└── prd.md                    ← Product Requirements Document
```

---

## API Reference

All endpoints are prefixed with `/api/v1/mobile` (configurable via `API_PREFIX` env var).

| Method | Endpoint              | Auth   | Description                        |
| ------ | --------------------- | ------ | ---------------------------------- |
| `GET`  | `/health`             | No     | Health check (unprefixed)          |
| `POST` | `/auth/login`         | No     | Authenticate via Odoo, returns JWT |
| `POST` | `/auth/refresh`       | No     | Exchange refresh token for a fresh access token |
| `GET`  | `/auth/me`            | Bearer | Get current user principal         |
| `GET`  | `/schema/:model`      | Bearer | Get mobile form schema for model   |
| `GET`  | `/records/:model`     | Bearer | List records with pagination       |
| `GET`  | `/records/:model/:id` | Bearer | Get single record by ID            |
| `POST` | `/records/:model`     | Bearer | Create a record and read it back canonically |
| `PATCH`| `/records/:model/:id` | Bearer | Update a record and read it back canonically |
| `DELETE`| `/records/:model/:id`| Bearer | Delete a record |
| `POST` | `/records/:model/:id/actions/:name` | Bearer | Execute a record-level action |
| `GET`  | `/search/:model`      | Bearer | Name search (autocomplete)         |

### Response Envelope

All responses follow a consistent envelope:

```json
{
  "success": true,
  "data": { ... },
  "meta": { "total": 100, "offset": 0, "limit": 40 },
  "errors": []
}
```

---

## Odoo Compatibility

| Feature                            |  v17  |  v18  |  v19  |
| ---------------------------------- | :---: | :---: | :---: |
| JSON-RPC (`/jsonrpc`)              |   ✅   |   ✅   |   ✅   |
| `fields_get` introspection         |   ✅   |   ✅   |   ✅   |
| `get_view(view_type='form')`       |   ✅   |   ✅   |   ✅   |
| `search_read`                      |   ✅   |   ✅   |   ✅   |
| `name_search`                      |   ✅   |   ✅   |   ✅   |
| Session-based authentication       |   ✅   |   ✅   |   ✅   |
| `groups_id` / `group_ids` fallback |   ✅   |   ✅   |   ✅   |

The **Version Adapter** pattern normalizes API differences. Adding support for a new Odoo version requires a single adapter file.

---

## Roadmap

### Completed

- [x] **Handoff 1 — Foundation** — Monorepo setup, shared contracts, NestJS bootstrap, health check
- [x] **Handoff 2 — Auth & RPC** — Auth module, JWT, version detection, JSON-RPC client, live Odoo 17/18/19 validation
- [x] **Handoff 3 — Schema & Records** — Session bridge, schema/records/search endpoints, live validation
- [x] **Handoff 4 — Hardening** — Backend test suite, regression tests, docs cleanup
- [x] **Handoff 5 — iOS MVP** — SwiftUI app shell, login, session restore, API client, offline cache, res.partner browsing

### Phase 1 — Core Forms *(Complete through Phase 04)*

- [x] Token refresh backend (`POST /auth/refresh`)
- [x] Dynamic form foundation — render forms from schema JSON
- [x] Backend record create / edit / delete endpoints
- [x] Backend workflow action endpoints
- [x] iOS auto-refresh
- [x] iOS form save/write integration
- [x] `many2one` editor flow
- [x] Additional models: `crm.lead`, `sale.order`

### Phase 1.5 — Hardening & Docs *(Complete)*

- [x] Full regression confirmation across backend + iOS write flows
- [x] Broaden iOS test coverage around save failures and relation edge cases
- [x] Final docs cleanup for the completed write slice

### Phase 2 — Production Hardening *(In Progress)*

- [x] Redis session store (replace in-memory `Map`)
- [x] Schema caching with Redis (1h TTL)
- [x] Rate limiting on auth endpoints
- [x] CORS configuration
- [x] Structured logging (Pino)
- [x] iOS test hardening (unit-green milestone reached; recent-items relaunch UI path documented as a known simulator boundary for the next iOS phase)
- [ ] Phase 06A — isolate recent-items relaunch determinism before any observation refactor
- [ ] Phase 06B — run a narrow `RecentItemsStore` `@Observable` pilot
- [ ] Phase 07 — widen `@Observable` migration to `AppState`, feature view models, and `FormDraft` only after the pilot is green

### Phase 3 — Inventory & Offline

- [ ] Barcode scanner (AVFoundation)
- [ ] Inventory transfer workflows
- [ ] Offline sync engine with conflict resolution
- [ ] SwiftData / Core Data local store
- [ ] Complex field types (one2many, many2many, binary)

### Phase 4 — Notifications & Polish

- [ ] Push notifications (APNs)
- [ ] WebSocket real-time updates (Socket.IO)
- [ ] Biometric authentication (Face ID / Touch ID)
- [ ] Multi-server support + server switcher
- [ ] Dark mode polish
- [ ] App Store submission

### Phase 5 — AI & Advanced *(Future)*

- [ ] AI assistant for smart data entry
- [ ] Camera OCR for documents
- [ ] Voice input for notes and search
- [ ] iPad-optimized layouts
- [ ] Swagger / OpenAPI documentation
- [ ] Android app (Kotlin / KMP)

---

## Documentation

| Document                                                     | Description                      |
| ------------------------------------------------------------ | -------------------------------- |
| [`prd.md`](prd.md)                                           | Product Requirements Document    |
| [`docs/system-architecture.md`](docs/system-architecture.md) | System architecture overview     |
| [`docs/code-standards.md`](docs/code-standards.md)           | Coding standards and conventions |
| [`docs/codebase-summary.md`](docs/codebase-summary.md)       | Codebase summary and module map  |
| [`docs/project-roadmap.md`](docs/project-roadmap.md)         | Handoff status tracker           |
| [`docs/project-changelog.md`](docs/project-changelog.md)     | Change log                       |
| [`docs/deployment-guide.md`](docs/deployment-guide.md)       | Deployment instructions          |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.

---

## License

This project is private and not yet licensed for public distribution.

---

<p align="center">
  Built with ❤️ for the Odoo Community
</p>