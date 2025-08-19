###############################################
# Multistage Dockerfile for Node.js Application
###############################################

# ----------- Stage 1: Build Dependencies -----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production

# ----------- Stage 2: Copy Source & Build -----------
FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# If you have any build steps (e.g., transpile, assets), add here
# RUN npm run build

# ----------- Stage 3: Production Image -----------
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=development
COPY --from=build /app .
EXPOSE 3000
CMD ["node", "server.js"]

# ----------- Healthcheck (Optional) -----------
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --spider -q http://localhost:3000/ || exit 1
