# define nginx version
ARG nginx_version=1.23.1

FROM node:16.16.0-bullseye as app_builder
# make the 'app' folder the current working directory
WORKDIR /app
# copy both 'package.json' and 'package-lock.json' (if available)
COPY package*.json ./
# update npm
RUN npm install -g npm@8.17.0
# install project dependencies
RUN npm install --legacy-peer-deps
# copy project files and folders to the current working directory (i.e. 'app' folder)
COPY . .
# build app for production with minification
RUN npm run build


# nginx builder for brotli module and modules needed for nonce generation
FROM nginx:${nginx_version} AS brotli_nonce_builder
ARG nginx_version
WORKDIR /root/
RUN apt-get update \
    && apt-get install -y build-essential git wget libpcre3 libpcre3-dev libssl-dev zlib1g zlib1g-dev openssl gcc make libbrotli-dev \
    && wget http://nginx.org/download/nginx-${nginx_version}.tar.gz \
    && tar zxf nginx-${nginx_version}.tar.gz \
    && wget https://github.com/openresty/set-misc-nginx-module/archive/refs/tags/v0.33.tar.gz \
    && tar zxf v0.33.tar.gz \
    && wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v0.3.1.tar.gz \
    && tar zxf v0.3.1.tar.gz \
    && git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli \
    && cd nginx-${nginx_version} \
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


# nginx state for serving content
FROM nginx:${nginx_version}
ARG nginx_version
# add time zone
ENV TIME_ZONE=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && echo $TIME_ZONE > /etc/timezone
# copy brotli module files from brotli_nonce_builder
COPY --from=brotli_nonce_builder /root/nginx-${nginx_version}/objs/ngx_http_brotli_filter_module.so /usr/lib/nginx/modules/
COPY --from=brotli_nonce_builder /root/nginx-${nginx_version}/objs/ngx_http_brotli_static_module.so /usr/lib/nginx/modules/
COPY --from=brotli_nonce_builder /root/nginx-${nginx_version}/objs/ndk_http_module.so /usr/lib/nginx/modules/
COPY --from=brotli_nonce_builder /root/nginx-${nginx_version}/objs/ngx_http_set_misc_module.so /usr/lib/nginx/modules/
# remove and add new configs
RUN rm /etc/nginx/conf.d/default.conf
COPY ./docker/nginx/prod.conf /etc/nginx/conf.d/
COPY ./docker/nginx/nginx.conf /etc/nginx/
COPY ./docker/nginx/*.pem /etc/nginx/certificates/
COPY ./docker/nginx/*.key /etc/nginx/certificates/
# Set working directory to nginx asset directory
WORKDIR /usr/share/nginx/html
# Remove default nginx static assets
RUN rm -rf ./*
# Copy static assets from app_builder stage
COPY --from=app_builder /app/dist .
# Containers run nginx with global directives and daemon off
EXPOSE 443
ENTRYPOINT ["nginx", "-g", "daemon off;"]