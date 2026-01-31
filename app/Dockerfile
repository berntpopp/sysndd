# Build arguments
ARG NODE_VERSION=24
ARG NGINX_VERSION=1.27.4
ARG VUE_MODE=docker

# Stage 1: Build Vue.js application with Vite
FROM node:${NODE_VERSION}-alpine AS builder

# Build mode: docker (default), production, development
ARG VUE_MODE

# Set working directory
WORKDIR /app

# Copy dependency manifests (cache optimization layer)
COPY package*.json ./

# Install dependencies with BuildKit cache mount
# --legacy-peer-deps required by existing package.json
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund --legacy-peer-deps

# Copy application source
COPY . .

# Build production bundle with Vite
# Uses build:docker for docker mode, build:production for production mode
RUN npm run build:${VUE_MODE}


# Stage 2: Production nginx server (using pre-built brotli image)
# fholzer/nginx-brotli has brotli pre-compiled - no 5 min compilation!
# Source: https://hub.docker.com/r/fholzer/nginx-brotli
# Pin to specific version for reproducible builds and supply chain security
FROM fholzer/nginx-brotli:v1.28.0 AS production

# Configure for non-root operation (similar to nginx-unprivileged)
# Create nginx user if not exists and set permissions
RUN sed -i 's/listen\s*80;/listen 8080;/g' /etc/nginx/conf.d/default.conf 2>/dev/null || true \
    && sed -i 's/pid\s*\/var\/run\/nginx.pid;/pid \/tmp\/nginx.pid;/g' /etc/nginx/nginx.conf \
    && mkdir -p /var/cache/nginx /var/log/nginx /tmp \
    && chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/conf.d /usr/share/nginx/html

# Copy nginx configuration (overwrites defaults)
COPY --chown=nginx:nginx ./docker/nginx/local.conf /etc/nginx/conf.d/default.conf
COPY --chown=nginx:nginx ./docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Set working directory to nginx asset directory
WORKDIR /usr/share/nginx/html

# Remove default nginx static assets
RUN rm -rf ./*

# Copy static assets from builder stage
COPY --chown=nginx:nginx --from=builder /app/dist .

# Health check using wget (included in Alpine)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider --tries=1 --no-verbose http://localhost:8080/ || exit 1

# Expose non-privileged port
EXPOSE 8080

# Switch to non-root user
USER nginx

# Run nginx
ENTRYPOINT ["nginx", "-g", "daemon off;"]
