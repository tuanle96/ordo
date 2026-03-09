---
description: How to run and manage the Ordo backend development environment
---

## Backend Dev Environment

The backend runs via **Docker Compose**, NOT inline terminal commands like `npm run start:dev`.

### Architecture
- `docker-compose.yml` at project root defines `backend` and `redis` services
- Backend container uses hot-reload: `./backend/src` and `./shared/src` are volume-mounted
- Source code changes auto-reload inside the container (no rebuild needed for code changes)
- Redis runs as a separate container (`ordo-redis`) on port 38425

### Common Commands

// turbo-all

1. Start all services:
```bash
cd /Volumes/DATA/Developments/Odoo/Ordo && docker compose up -d
```

2. View backend logs:
```bash
cd /Volumes/DATA/Developments/Odoo/Ordo && docker compose logs -f backend
```

3. Restart backend (after config/dependency changes):
```bash
cd /Volumes/DATA/Developments/Odoo/Ordo && docker compose restart backend
```

4. Rebuild backend (after Dockerfile or dependency changes):
```bash
cd /Volumes/DATA/Developments/Odoo/Ordo && docker compose up -d --build backend
```

5. Flush Redis cache (e.g., stale schema cache):
```bash
docker exec ordo-redis redis-cli FLUSHDB
```

6. Check specific Redis keys:
```bash
docker exec ordo-redis redis-cli KEYS "ordo:schema:*"
```

### Important Notes
- Backend is accessible at `http://localhost:38424`
- Redis is accessible at `localhost:38425` (mapped from container port 6379)
- Odoo instances are in a separate `docker-compose.yml` at `odoo-instances/`
- Schema cache TTL is 300 seconds (5 minutes) in Redis
- DO NOT suggest `npm run start:dev` — always use Docker Compose
