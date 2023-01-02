FROM nginx:1.23.3 AS builder

COPY ./nginx-quic                   /usr/src/nginx-quic
COPY ./libressl                     /usr/src/libressl
COPY ./modules/njs                  /usr/src/njs
COPY ./modules/ngx_brotli           /usr/src/ngx_brotli
COPY ./modules/zstd-nginx-module    /usr/src/zstd-nginx-module
COPY ./modules/nginx-module-vts     /usr/src/nginx-module-vts
COPY ./modules/ngx_http_geoip2_module \
                                    /usr/src/ngx_http_geoip2_module
COPY ./modules/ngx-fancyindex       /usr/src/ngx-fancyindex
COPY ./modules/ngx_http_substitutions_filter_module \
                                    /usr/src/ngx_http_substitutions_filter_module
COPY ./modules/headers-more-nginx-module \
                                    /usr/src/headers-more-nginx-module

# install build dependencies
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
        libpcre3-dev \
        zlib1g-dev \
        libgd-dev \
        libgeoip-dev \
        libmaxminddb-dev \
        libxslt1-dev \
        libzstd-dev

# build libressl (instead of openssl for QUIC support)
RUN set -ex \
    && cd /usr/src/libressl \
    && ./autogen.sh \
    && ./configure \
        --prefix=/opt/libressl \
        --disable-tests \
        --enable-shared=yes \
        --enable-static=no \
    && make -j$(nproc) install_sw \
# copy dynamic libraries to /usr/lib so nginx can find them
    && find /opt/libressl/lib -name '*.so.*' -exec cp -P {} /usr/lib \;

# build nginx-quic
RUN set -ex \
    && cd /usr/src/nginx-quic \
    && echo ./auto/configure \
# use the same configure arguments as the official nginx build
        $( \
            /usr/sbin/nginx -V 2>&1 \
            | grep 'configure arguments:' \
            | sed 's#.*arguments: ##' \
# but use libressl instead of openssl for QUIC
            | sed "s#--with-cc-opt='#--with-cc-opt='-I/opt/libressl/include #" \
            | sed "s#--with-ld-opt='#--with-ld-opt='-L/opt/libressl/lib #" \
        ) \
# add HTTP/3 and QUIC support
        --with-http_v3_module \
        --with-stream_quic_module \
        | bash -x \
# build nginx
    && make -j$(nproc) \
# just replace /usr/sbin/nginx with the new binary
    && cp ./objs/nginx /usr/sbin/nginx

# build dynamic modules
RUN set -ex \
    && cd /usr/src/nginx-quic \
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
        --add-dynamic-module=/usr/src/zstd-nginx-module \
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

# ==================================================================================================== #

FROM nginx:1.23.3

# remove old modules
RUN rm -rf /usr/lib/nginx/modules

# copy nginx binary and modules from builder
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules
# copy libressl dynamic libraries from builder
COPY --from=builder /usr/lib/libcrypto.so* /usr/lib/
COPY --from=builder /usr/lib/libssl.so* /usr/lib/

# install runtime dependencies
RUN set -ex \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        libgd3 \
        libgeoip1 \
        libxslt1.1 \
        libmaxminddb0 \
        libzstd1 \
    && rm -rf /var/lib/apt/lists/*
