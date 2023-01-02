# NGINX docker image for HTTP/3 (QUIC) support

[![build][gha-badge]][gha-link]
[![dockerhub pulls][dockerhub-pull-badge]][dockerhub-tags]
[![dockerhub size][dockerhub-size-badge]][dockerhub-tags]
[![dockerhub version][dockerhub-version-badge]][dockerhub-tags]
[![license][license-badge]][license]
[![arch][arch-badge]][dockerhub-tags]

[gha-badge]: https://github.com/nginx-quic/docker-nginx-quic/actions/workflows/ci.yml/badge.svg
[gha-link]: https://github.com/nginx-quic/docker-nginx-quic/actions/workflows/ci.yml
[dockerhub-tags]: https://hub.docker.com/r/zengxs/nginx-quic/tags
[dockerhub-pull-badge]: https://img.shields.io/docker/pulls/zengxs/nginx-quic?logo=docker
[dockerhub-size-badge]: https://img.shields.io/docker/image-size/zengxs/nginx-quic?logo=docker
[dockerhub-version-badge]: https://img.shields.io/docker/v/zengxs/nginx-quic?logo=docker
[license-badge]: https://img.shields.io/github/license/nginx-quic/nginx-quic
[license]: ./LICENSE
[arch-badge]: https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-lightgrey
[libressl]: https://www.libressl.org/
[quictls]: https://github.com/quictls/openssl/
[boringssl]: https://boringssl.googlesource.com/boringssl/

Drop-in replacement for the official NGINX docker image, with HTTP/3 (QUIC) support.

## What is this image?

NGINX now has support for HTTP/3 (QUIC), but the official docker image doesn't have it.
this image is a drop-in replacement for the official image, with HTTP/3 (QUIC) support.

This image is based on the official NGINX docker image and adds support for HTTP/3 (QUIC)
using the [LibreSSL][libressl] library. The image use the same build configuration as the
official image, and just update the NGINX binary to support HTTP/3.

Also, the image adds some popular third-party modules, they are linked dynamically, that
means there will be no overhead if you don't use them. But if you want to use them, you
don't need to build your own image, just add some `load_module` directives in your NGINX
configuration file.

Other than that, the image is the same as the official one, so you can use it as a drop-in
replacement for the official image.

## Why LibreSSL?

At this moment, NGINX can use three SSL implementations to support HTTP/3 (QUIC):
[BoringSSL][boringssl], [QuicTLS][quictls] and [LibreSSL][libressl].

BoringSSL is Google's fork of OpenSSL and it is used by Chromium and Google's other projects.
It is not aims server-side use, and it documented:

> 1. that is designed to meet Google's needs.
> 2. it is not intended for general use.
> 3. We don't recommend that third parties depend upon it.

QuicTLS is a fork of OpenSSL enabled with QUIC support, but it's not ready for production.

LibreSSL is a fork of OpenSSL, it is a security-focused, modern version of the TLS/crypto
library. It is a drop-in replacement for OpenSSL, and it is used by many projects, such as
OpenSSH, OpenBSD, macOS, etc.

So I think LibreSSL is the best choice for this image.

## How to pull the image?

```sh
# Pull the image from GitHub Container Registry
docker pull ghcr.io/nginx-quic/nginx-quic

# Or pull the image from Docker Hub
docker pull zengxs/nginx-quic
```

## Third-party modules

| Module                                                  | Description                                    | Dynamic module file name                                              |
| ------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------------- |
| [ngx_brotli][mod-brotli]                                | Brotli compression module maintained by Google | ngx_http_brotli_filter_module.so<br/>ngx_http_brotli_static_module.so |
| [zstd-nginx-module][mod-zstd]                           | Zstandard compression module                   | ngx_http_zstd_filter_module.so<br/>ngx_http_zstd_static_module.so     |
| [headers-more-nginx-module][mod-headers-more]           | More set of headers for NGINX                  | ngx_http_headers_more_filter_module.so                                |
| [nginx-module-vts][mod-vts]                             | Nginx virtual host traffic status module       | ngx_http_vhost_traffic_status_module.so                               |
| [ngx_http_geoip2_module][mod-geoip2]                    | GeoIP2 module for NGINX                        | ngx_http_geoip2_module.so<br/>ngx_stream_geoip2_module.so             |
| [ngx-fancyindex][mod-fancyindex]                        | Fancy indexes module for NGINX                 | ngx_http_fancyindex_module.so                                         |
| [ngx_http_substitutions_filter_module][mod-subs-filter] | Substitutions filter module for NGINX          | ngx_http_subs_filter_module.so                                        |

[mod-brotli]: https://github.com/google/ngx_brotli
[mod-zstd]: https://github.com/tokers/zstd-nginx-module
[mod-headers-more]: https://github.com/openresty/headers-more-nginx-module
[mod-vts]: https://github.com/vozlt/nginx-module-vts
[mod-geoip2]: https://github.com/leev/ngx_http_geoip2_module
[mod-fancyindex]: https://github.com/aperezdc/ngx-fancyindex
[mod-subs-filter]: https://github.com/yaoweibin/ngx_http_substitutions_filter_module

Also you can ls the `/usr/lib/nginx/modules` directory to see all the available dynamic modules:

```sh
docker run --rm -it ghcr.io/nginx-quic/nginx-quic ls -lh /usr/lib/nginx/modules/
```

You can enable them by simply adding some `load_module` directives in your NGINX configuration:

```nginx
load_module modules/ngx_http_brotli_filter_module.so;
load_module modules/ngx_http_brotli_static_module.so;
```

## License

All submodules are licensed under their own licenses. Other files are licensed under the
[MIT License][license] unless otherwise specified.
