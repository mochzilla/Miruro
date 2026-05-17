# syntax=docker/dockerfile:1.7

# ---------- Stage 1: builder ----------
# Full Bun image so we have everything needed to install deps and run `vite build`.
FROM oven/bun:1 AS builder
WORKDIR /app

# Install deps first so this layer is cached across source-only changes.
# bun.lockb is gitignored in this repo, so the glob makes the COPY optional.
COPY package.json ./
COPY bun.lockb* ./
RUN bun install

# Copy the rest of the source tree.
COPY . .

# Vite inlines VITE_* variables at build time. Pass them with:
#   docker build --build-arg VITE_BACKEND_URL=https://... .
ARG VITE_BACKEND_URL
ARG VITE_SKIP_TIMES
ARG VITE_PROXY_URL
ARG VITE_API_KEY
ARG VITE_GA_MEASUREMENT_ID
ARG VITE_DEPLOY_PLATFORM
ARG VITE_PORT

RUN bun run build

# ---------- Stage 2: runtime ----------
# Slim Bun image — no build tooling, just the runtime that executes server.ts.
FROM oven/bun:1-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Only the artifacts the Express server needs at runtime.
# server.ts resolves `path.join(__dirname, '../dist')`, so `dist` must sit
# alongside `server` under /app.
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server ./server

# Drop privileges — the oven/bun image ships a non-root `bun` user.
USER bun

# Default port from .env.example / vite.config.ts; override with -e VITE_PORT=...
EXPOSE 5173

CMD ["bun", "run", "./server/server.ts"]
