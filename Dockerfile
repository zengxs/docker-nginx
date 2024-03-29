ARG NGINX_VERSION=1.25.2

# ==================================================================================================== #
FROM nginx:${NGINX_VERSION} AS builder

# NOTE: add new dependencies in each stage, so that the cache is invalidated only when necessary

# install build dependencies common to all builds
RUN set -ex \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        automake \
        autoconf \
        libtool \
        ca-certificates \
        curl \
        libssl-dev \
        libpcre3-dev \
        zlib1g-dev

# install build dependencies for additional dynamic modules
RUN set -ex \
    && apt-get install -y --no-install-recommends \
        libedit-dev \
        libgd-dev \
        libgeoip-dev \
        libmaxminddb-dev \
        libxslt1-dev

# copy dynamic modules source code
COPY ./nginx                        /usr/src/nginx
COPY ./modules/njs                  /usr/src/njs
COPY ./modules/ngx_brotli           /usr/src/ngx_brotli
COPY ./modules/nginx-module-vts     /usr/src/nginx-module-vts
COPY ./modules/ngx_http_geoip2_module \
                                    /usr/src/ngx_http_geoip2_module
COPY ./modules/ngx-fancyindex       /usr/src/ngx-fancyindex
COPY ./modules/ngx_http_substitutions_filter_module \
                                    /usr/src/ngx_http_substitutions_filter_module
COPY ./modules/headers-more-nginx-module \
                                    /usr/src/headers-more-nginx-module

RUN set -ex \
    && cd /usr/src/nginx \
    && echo ./auto/configure \
# all dynamic modules need to be built with the same configure arguments as nginx
        $(/usr/sbin/nginx -V 2>&1 | grep 'configure arguments:' | sed 's#.*arguments: ##') \
# dynamic modules shipped with official nginx docker image (requires rebuild)
        --with-http_xslt_module=dynamic \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --with-stream_geoip_module=dynamic \
        --add-dynamic-module=/usr/src/njs/nginx \
# third-party dynamic modules
        --add-dynamic-module=/usr/src/ngx_brotli \
        --add-dynamic-module=/usr/src/nginx-module-vts \
        --add-dynamic-module=/usr/src/ngx_http_geoip2_module \
        --add-dynamic-module=/usr/src/ngx-fancyindex \
        --add-dynamic-module=/usr/src/ngx_http_substitutions_filter_module \
        --add-dynamic-module=/usr/src/headers-more-nginx-module \
        | bash -x \
# build modules
    && make modules -j$(nproc) \
# remove old modules
    && rm -rf /usr/lib/nginx/modules/* \
# move new modules to /usr/lib/nginx/modules
    && find ./objs -name 'ngx*.so' | xargs -I{} mv {} /usr/lib/nginx/modules/

# build njs command-line utility
RUN set -ex \
    && cd /usr/src/njs \
    && ./configure \
    && make njs -j$(nproc) \
    && cp ./build/njs /usr/bin/njs \
    && chmod +x /usr/bin/njs

# download GeoIP2 databases
RUN set -ex \
    && mkdir -p /usr/share/GeoIP \
    && curl -sSL -o /usr/share/GeoIP/GeoLite2-ASN.mmdb \
        https://github.com/P3TERX/GeoLite.mmdb/releases/latest/download/GeoLite2-ASN.mmdb \
    && curl -sSL -o /usr/share/GeoIP/GeoLite2-City.mmdb \
        https://github.com/P3TERX/GeoLite.mmdb/releases/latest/download/GeoLite2-City.mmdb \
    && curl -sSL -o /usr/share/GeoIP/GeoLite2-Country.mmdb \
        https://github.com/P3TERX/GeoLite.mmdb/releases/latest/download/GeoLite2-Country.mmdb

# ==================================================================================================== #
FROM node AS njs-acme-builder

WORKDIR /app
COPY ./modules/njs-acme .

RUN set -ex \
    && npm install \
    && npm run build

# ==================================================================================================== #
FROM nginx:${NGINX_VERSION}

# remove old modules
RUN rm -rf /usr/lib/nginx/modules

# copy build artifacts from builder stage
COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules
COPY --from=builder /usr/bin/njs /usr/bin/njs
COPY --from=builder /usr/share/GeoIP /usr/share/GeoIP
COPY --from=njs-acme-builder /app/dist/acme.js /usr/lib/nginx/njs_modules/acme.js

# install runtime dependencies
RUN set -ex \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        libpcre3 \
        libgd3 \
        libgeoip1 \
        libxslt1.1 \
        libmaxminddb0 \
        libzstd1 \
    && rm -rf /var/lib/apt/lists/*
