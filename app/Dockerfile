# Build arguments
ARG NODE_VERSION=20
ARG NGINX_VERSION=1.27.4
ARG VUE_MODE=docker

# Stage 1: Build Vue.js application
# NOTE: Node.js 20 LTS required for Vue 2.7 + Vue CLI 5 + webpack 5 compatibility
# Upgrade to node:24-alpine after Vue 3 migration (Phase 10+)
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

# Build production bundle
RUN npm run build -- --mode ${VUE_MODE}


# Stage 2: nginx builder for brotli module and modules needed for nonce generation
FROM nginx:${NGINX_VERSION} AS brotli_nonce_builder
ARG NGINX_VERSION

WORKDIR /root/
RUN apt-get update \
    && apt-get install -y build-essential git wget libpcre3 libpcre3-dev libssl-dev zlib1g zlib1g-dev openssl gcc make libbrotli-dev \
    && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar zxf nginx-${NGINX_VERSION}.tar.gz \
    && wget https://github.com/openresty/set-misc-nginx-module/archive/refs/tags/v0.33.tar.gz \
    && tar zxf v0.33.tar.gz \
    && wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v0.3.1.tar.gz \
    && tar zxf v0.3.1.tar.gz \
    && git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli \
    && cd nginx-${NGINX_VERSION} \
    && ./configure \
    --add-dynamic-module=../ngx_brotli \
    --add-dynamic-module=../ngx_devel_kit-0.3.1 \
    --add-dynamic-module=../set-misc-nginx-module-0.33 \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-perl_modules_path=/usr/lib/perl5/vendor_perl \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt='-Os -fomit-frame-pointer -g' \
    --with-ld-opt=-Wl,--as-needed,-O1,--sort-common \
    && make modules


# Stage 3: Production nginx server
FROM nginxinc/nginx-unprivileged:${NGINX_VERSION}-alpine
ARG NGINX_VERSION

# Copy brotli module files from brotli_nonce_builder
COPY --chown=nginx:nginx --from=brotli_nonce_builder /root/nginx-${NGINX_VERSION}/objs/ngx_http_brotli_filter_module.so /usr/lib/nginx/modules/
COPY --chown=nginx:nginx --from=brotli_nonce_builder /root/nginx-${NGINX_VERSION}/objs/ngx_http_brotli_static_module.so /usr/lib/nginx/modules/
COPY --chown=nginx:nginx --from=brotli_nonce_builder /root/nginx-${NGINX_VERSION}/objs/ndk_http_module.so /usr/lib/nginx/modules/
COPY --chown=nginx:nginx --from=brotli_nonce_builder /root/nginx-${NGINX_VERSION}/objs/ngx_http_set_misc_module.so /usr/lib/nginx/modules/

# Copy nginx configuration
# Use local.conf for Docker Compose development (no SSL, no alb upstream)
# For production deployment, use prod.conf with SSL certificates
COPY --chown=nginx:nginx ./docker/nginx/local.conf /etc/nginx/conf.d/default.conf
COPY --chown=nginx:nginx ./docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Set working directory to nginx asset directory
WORKDIR /usr/share/nginx/html

# Copy static assets from builder stage
COPY --chown=nginx:nginx --from=builder /app/dist .

# Health check using wget (included in Alpine busybox)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --spider --tries=1 --no-verbose http://localhost:8080/ || exit 1

# Expose non-privileged port
EXPOSE 8080

# Container runs as nginx user (UID 101) - inherited from base image
# ENTRYPOINT inherited from nginxinc/nginx-unprivileged
