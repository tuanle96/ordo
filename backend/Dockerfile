# ============================================================
# Stage 1: Development (hot reload with nest start --watch)
# ============================================================
FROM node:22-alpine AS dev

WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy config and source (will be overridden by volume mount in dev)
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src

# Expose the dev port
EXPOSE 38424

# Start NestJS in watch mode
CMD ["npm", "run", "start:dev"]

# ============================================================
# Stage 2: Build (compile TypeScript for production)
# ============================================================
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src

RUN npm ci
RUN npm run build

# Prune devDependencies
RUN npm prune --production

# ============================================================
# Stage 3: Production (minimal runtime image)
# ============================================================
FROM node:22-alpine AS production

WORKDIR /app

# Copy only what's needed to run
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist

EXPOSE 38424

ENV NODE_ENV=production

CMD ["node", "dist/main.js"]
