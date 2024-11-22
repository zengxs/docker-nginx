# NGINX docker image with many useful modules

[![build][gha-badge]][gha-link]
[![dockerhub pulls][dockerhub-pull-badge]][dockerhub-tags]
[![dockerhub size][dockerhub-size-badge]][dockerhub-tags]
[![dockerhub version][dockerhub-version-badge]][dockerhub-tags]
[![license][license-badge]][license]
[![arch][arch-badge]][dockerhub-tags]

[gha-badge]: https://github.com/zengxs/docker-nginx/actions/workflows/ci.yml/badge.svg
[gha-link]: https://github.com/zengxs/docker-nginx/actions/workflows/ci.yml
[dockerhub-tags]: https://hub.docker.com/r/zengxs/nginx/tags
[dockerhub-pull-badge]: https://img.shields.io/docker/pulls/zengxs/nginx?logo=docker
[dockerhub-size-badge]: https://img.shields.io/docker/image-size/zengxs/nginx?logo=docker
[dockerhub-version-badge]: https://img.shields.io/docker/v/zengxs/nginx?logo=docker
[license-badge]: https://img.shields.io/github/license/zengxs/docker-nginx
[license]: ./LICENSE
[arch-badge]: https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-lightgrey

Drop-in replacement for the official nginx image with many useful modules.

You can use it just like the official image without any changes, but you can enjoy many
useful modules that are not included in the official image by adding some simple `load_module`
directives in your NGINX configuration.

> **NOTE**: This image is based on the official image debian variant, and all default
> configurations are the same as the official image. So you must explicitly enable the
> modules you want to use, otherwise this image will not be different from the official
> image.

## How to use this image?

Just replace the official image name with this image name from your docker-compose file or
other docker commands.

Change your docker-compose file like this:

```diff
 version: '3.9'
 services:
   nginx:
-    image: nginx:1.27.2
+    image: zengxs/nginx:1.27.2
```

Or change your docker command like this:

```diff
 docker run -d \
   --name nginx \
   --restart=always \
   -v $PWD/conf.d:/etc/nginx/conf.d \
   -v $PWD/certs:/etc/nginx/certs \
   -p 80:80 -p 443:443 \
-  nginx:1.27.2
+  zengxs/nginx:1.27.2
```

## Third-party modules

### Dynamic modules

| Module                                                  | Description                                                    | Dynamic module file name                                              |
| ------------------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------- |
| [ngx_brotli][mod-brotli]                                | Brotli compression module maintained by Google                 | ngx_http_brotli_filter_module.so<br/>ngx_http_brotli_static_module.so |
| [headers-more-nginx-module][mod-headers-more]           | More set of headers for NGINX                                  | ngx_http_headers_more_filter_module.so                                |
| [nginx-module-vts][mod-vts]                             | Nginx virtual host traffic status module                       | ngx_http_vhost_traffic_status_module.so                               |
| [ngx_http_geoip2_module][mod-geoip2]                    | GeoIP2 module for NGINX (GeoLite2 database included[^geolite]) | ngx_http_geoip2_module.so<br/>ngx_stream_geoip2_module.so             |
| [ngx-fancyindex][mod-fancyindex]                        | Fancy indexes module for NGINX                                 | ngx_http_fancyindex_module.so                                         |
| [ngx_http_substitutions_filter_module][mod-subs-filter] | Substitutions filter module for NGINX                          | ngx_http_subs_filter_module.so                                        |

[mod-brotli]: https://github.com/google/ngx_brotli
[mod-headers-more]: https://github.com/openresty/headers-more-nginx-module
[mod-vts]: https://github.com/vozlt/nginx-module-vts
[mod-geoip2]: https://github.com/leev/ngx_http_geoip2_module
[mod-fancyindex]: https://github.com/aperezdc/ngx-fancyindex
[mod-subs-filter]: https://github.com/yaoweibin/ngx_http_substitutions_filter_module

[^geolite]: GeoLite2 database is located at `/usr/share/GeoIP/GeoLite2-{ASN,City,Country}.mmdb`.

All dynamic modules are installed in `/usr/lib/nginx/modules` directory. You can use the
following command to list them:

```sh
docker run --rm -it zengxs/nginx ls -lh /usr/lib/nginx/modules/
```

You can enable them by simply adding some `load_module` directives in your NGINX configuration:

```nginx
load_module modules/ngx_http_brotli_filter_module.so;
load_module modules/ngx_http_brotli_static_module.so;
```

### `njs` modules

| Module                   | Description           | JS module file name |
| ------------------------ | --------------------- | ------------------- |
| [njs-acme][mod-njs-acme] | ACME module for NGINX | `acme.js`           |

[mod-njs-acme]: https://github.com/nginx/njs-acme

All `njs` modules are installed in `/usr/share/nginx/njs_modules` directory. You can use the
following command to list them:

```sh
docker run --rm -it zengxs/nginx ls -lh /usr/share/nginx/njs_modules/
```

You must enable the `njs` module to use `njs` modules:

```nginx
# load dynamic modules
load_module modules/ngx_http_js_module.so;
load_module modules/ngx_stream_js_module.so;

# set search path for njs
js_path /usr/share/nginx/njs_modules;
```

Then you can import njs modules in your NGINX configuration:

```nginx
js_import acme from 'acme.js';
```

## License

All submodules are licensed under their own licenses. Other files are licensed under the
[MIT License][license] unless otherwise specified.
