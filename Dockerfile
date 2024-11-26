ARG NGINX_VERSION

# ==================================================================================================== #
FROM nginx:${NGINX_VERSION} AS builder

# NOTE: add new dependencies in each stage, so that the cache is invalidated only when necessary

# install build dependencies common to all builds
RUN set -ex \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        cmake \
        bison \
        automake \
        autoconf \
        libtool \
        patchelf \
        ca-certificates \
        curl \
        libssl-dev \
        libpcre3-dev \
        zlib1g-dev \
        libmodsecurity-dev \
        libgrpc-dev \
        libgrpc++-dev \
        libprotobuf-dev \
        protobuf-compiler-grpc

# install build dependencies for additional dynamic modules
RUN set -ex \
    && apt-get install -y --no-install-recommends \
        libedit-dev \
        libgd-dev \
        libgeoip-dev \
        libmaxminddb-dev \
        libxslt1-dev

# copy nginx source code, modules, and third-party dependencies
COPY ./nginx                        /usr/src/nginx
COPY ./modules                      /usr/src/modules
COPY ./third-deps                   /usr/src/third-deps

# build third-party dependencies
RUN set -ex \
# sregex, required by replace-filter-nginx-module
    && cd /usr/src/third-deps/sregex \
    && make install PREFIX=/opt/sregex

ENV SREGEX_INC=/opt/sregex/include
ENV SREGEX_LIB=/opt/sregex/lib
ENV NGX_OTEL_CMAKE_OPTS="-D NGX_OTEL_GRPC=package"

# patch all .so file soname use absolute path
RUN set -ex \
    && find /opt -name 'lib*.so*' -exec patchelf --set-soname {} {} \;

# patch nginx-otel CMakeLists.txt find_package(protobuf) to find_package(Protobuf)
RUN set -ex \
    && sed -i 's/find_package(protobuf REQUIRED)/find_package(Protobuf REQUIRED)/' /usr/src/modules/nginx-otel/CMakeLists.txt

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
        --add-dynamic-module=/usr/src/modules/njs/nginx \
# third-party dynamic modules
        --add-dynamic-module=/usr/src/modules/ngx_brotli \
        --add-dynamic-module=/usr/src/modules/nginx-module-vts \
        --add-dynamic-module=/usr/src/modules/ngx_http_geoip2_module \
        --add-dynamic-module=/usr/src/modules/ngx-fancyindex \
        --add-dynamic-module=/usr/src/modules/ngx_http_substitutions_filter_module \
        --add-dynamic-module=/usr/src/modules/replace-filter-nginx-module \
        --add-dynamic-module=/usr/src/modules/headers-more-nginx-module \
        --add-dynamic-module=/usr/src/modules/ngx_devel_kit \
        --add-dynamic-module=/usr/src/modules/iconv-nginx-module \
        --add-dynamic-module=/usr/src/modules/ModSecurity-nginx \
        --add-dynamic-module=/usr/src/modules/naxsi/naxsi_src \
        --add-dynamic-module=/usr/src/modules/nginx-otel \
        | bash -x \
# build modules
    && make modules -j$(nproc) \
# remove old modules
    && rm -rf /usr/lib/nginx/modules/* \
# move new modules to /usr/lib/nginx/modules
    && find ./objs -name 'ngx*.so' | xargs -I{} mv {} /usr/lib/nginx/modules/

# build njs command-line utility
RUN set -ex \
    && cd /usr/src/modules/njs \
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
FROM node AS njs-builder

WORKDIR /app
COPY ./njs-modules .

RUN set -ex \
    && cd njs-acme \
    && npm install \
    && npm run build

# ==================================================================================================== #
FROM nginx:${NGINX_VERSION}

# remove old modules
RUN rm -rf /usr/lib/nginx/modules

# copy build artifacts from builder stage
COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules
COPY --from=builder /opt/sregex/lib /opt/sregex/lib
COPY --from=builder /usr/bin/njs /usr/bin/njs
COPY --from=builder usr/src/modules/naxsi/naxsi_rules /etc/nginx/naxsi
COPY --from=builder /usr/share/GeoIP /usr/share/GeoIP
COPY --from=njs-builder /app/njs-acme/dist/acme.js /usr/lib/nginx/njs_modules/acme.js

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
        libgrpc29 \
        libgrpc++1.51 \
        libprotobuf32 \
        libmodsecurity3 \
        modsecurity-crs \
    && rm -rf /var/lib/apt/lists/*
