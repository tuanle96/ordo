# ============================================================
# Stage 1: Development (hot reload with nest start --watch)
# ============================================================
FROM node:22-alpine AS dev

WORKDIR /app

# Copy workspace root config
COPY package.json package-lock.json tsconfig.base.json ./

# Copy shared package
COPY shared/package.json shared/tsconfig.json ./shared/
COPY shared/src ./shared/src

# Copy backend package
COPY backend/package.json backend/tsconfig.json backend/tsconfig.build.json backend/nest-cli.json ./backend/

# Install all dependencies (including devDependencies)
RUN npm ci

# Build shared package (backend depends on it)
RUN npm run build --workspace shared

# Copy backend source (will be overridden by volume mount in dev)
COPY backend/src ./backend/src

# Expose the dev port
EXPOSE 38424

# Start NestJS in watch mode
CMD ["npm", "run", "start:dev", "--workspace", "backend"]

# ============================================================
# Stage 2: Build (compile TypeScript for production)
# ============================================================
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json tsconfig.base.json ./
COPY shared/ ./shared/
COPY backend/ ./backend/

RUN npm ci
RUN npm run build --workspace shared
RUN npm run build --workspace backend

# Prune devDependencies
RUN npm prune --production

# ============================================================
# Stage 3: Production (minimal runtime image)
# ============================================================
FROM node:22-alpine AS production

WORKDIR /app

# Copy only what's needed to run
COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/shared/package.json ./shared/package.json
COPY --from=build /app/shared/dist ./shared/dist
COPY --from=build /app/backend/package.json ./backend/package.json
COPY --from=build /app/backend/dist ./backend/dist

EXPOSE 38424

ENV NODE_ENV=production

CMD ["node", "backend/dist/main.js"]
