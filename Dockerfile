# Base image
FROM node:20.15.0-alpine AS base

# Builder stage
FROM base AS builder
RUN apk update
RUN apk add --no-cache libc6-compat
WORKDIR /app
RUN yarn global add turbo
COPY . .
RUN turbo prune web --docker

# Installer stage
FROM base AS installer
RUN apk update
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY apps/web/.gitignore .gitignore
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/yarn.lock ./yarn.lock
RUN yarn install

COPY --from=builder /app/out/full/ .
COPY turbo.json turbo.json

# Debugging step: Verify files before build
RUN ls -la /app

RUN yarn turbo build --filter=web...

# Debugging step: Verify build output
RUN ls -la /app/apps/web/.next || echo ".next directory not found"
RUN ls -la /app/apps/web/.next/standalone || echo "standalone directory not found"

# Runner stage
FROM base AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
USER nextjs

COPY --from=installer /app/apps/web/next.config.mjs .
COPY --from=installer /app/apps/web/package.json .

# Debugging step: Verify build output files before copying
RUN ls -la /app/apps/web/.next || echo ".next directory not found"
RUN ls -la /app/apps/web/.next/standalone || echo "standalone directory not found"

COPY --from=installer --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=installer --chown=nextjs:nodejs /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=installer --chown=nextjs:nodejs /app/apps/web/public ./apps/web/public

CMD node apps/web/server.js
