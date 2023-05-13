# syntax=docker/dockerfile:experimental
ARG NGINX_VERSION

FROM nginx:${NGINX_VERSION} as builder

ARG NGINX_VERSION
ARG MODSEC_VERSION=3.0.8
ARG LMDB_VERSION=0.9.29

RUN set -eux \
    ; apt-get update -qq \
    && LD_LIBRARY_PATH="" apt-get install -y -qq --no-install-recommends --no-install-suggests \
        cmake \
        curl \
        automake \
        cmake \
        doxygen \
        g++ \
        gcc \
        git \
        zlib1g \
        zlib1g-dev \
        libcurl4-gnutls-dev \
        libfuzzy-dev \
        libgeoip-dev \
        liblua5.1-dev \
        liblua5.3-dev \
        libpcre3 \
        libpcre3-dev \
        libssl-dev \
        libtool \
        libxml2 \
        libxml2-dev \
        libxslt1-dev \
        libyajl-dev \
        lua5.1 \
        make \
        openssh-client \
        openssl \
        patch \
        pkg-config \
        ruby \
        zlib1g-dev \
        unzip \
    && apt-get clean \
    && rm -rf /var/cache/apt /var/lib/lists/*

# Set up ModSecurity

WORKDIR /usr/src

RUN set -eux; \
    git clone https://github.com/LMDB/lmdb --branch LMDB_${LMDB_VERSION} --depth 1; \
    make -C lmdb/libraries/liblmdb install; \
    strip /usr/local/lib/liblmdb*.so*

# Build ModSecurity
RUN set -eux; \
    git clone https://github.com/SpiderLabs/ModSecurity --branch v"${MODSEC_VERSION}" --depth 1 --recursive; \
    cd ModSecurity; \
    ARCH=$(gcc -print-multiarch); \
    sed -ie "s/i386-linux-gnu/${ARCH}/g" build/ssdeep.m4; \
    sed -ie "s/i386-linux-gnu/${ARCH}/g" build/pcre2.m4; \
    ./build.sh; \
    ./configure --with-yajl --with-ssdeep --with-geoip --with-pcre2 --enable-silent-rules; \
    make install; \
    strip /usr/local/modsecurity/lib/lib*.so*

# Create ModSecurity configuration files.
RUN set -eux; \
    mkdir /etc/modsecurity.d; \
    curl -sSL https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended \
         -o /etc/modsecurity.d/modsecurity.conf; \
    curl -sSL https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping \
         -o /etc/modsecurity.d/unicode.mapping

# Generate/Download Diffie-Hellman parameter files
RUN set -eux; \
    mkdir -p /usr/share/TLS; \
    curl -sSL https://ssl-config.mozilla.org/ffdhe2048.txt -o /usr/share/TLS/dhparam-2048.pem; \
    curl -sSL https://ssl-config.mozilla.org/ffdhe4096.txt -o /usr/share/TLS/dhparam-4096.pem

# Set up modules

WORKDIR /usr/src/ModSecurity-nginx
RUN git clone -b master --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git .

WORKDIR /usr/src/lua-nginx-module
RUN git clone https://github.com/openresty/lua-nginx-module .

WORKDIR /usr/src/ngx_devel_kit
RUN git clone https://github.com/vision5/ngx_devel_kit .

WORKDIR /usr/src/lua-resty-logger-socket
RUN git clone https://github.com/cloudflare/lua-resty-logger-socket .

# Install Lua modules.
# NOTE: Apperently the LuaRocks version that can be installed via `apt` is old and does not support some package
# format used by one of the LuaRocks packages, so LuaRocks has to be installed separately...
RUN curl --location "https://luarocks.org/releases/luarocks-3.8.0.tar.gz" | tar --gunzip --extract --directory=/usr/src
WORKDIR /usr/src/luarocks-3.8.0
RUN ./configure --with-lua-include=/usr/include/lua5.1 && make install

WORKDIR /usr/src/lua_modules
RUN luarocks install base64 --tree . \
    && luarocks install lua-cjson --tree . \
    && rm -rf /usr/share/lua/5.1/luarocks

WORKDIR /usr/src/lua-resty-core
RUN git clone https://github.com/openresty/lua-resty-core . && make install LUA_LIB_DIR=/usr/local/share/lua/5.1/

WORKDIR /usr/src/lua-resty-lrucache
RUN git clone https://github.com/openresty/lua-resty-lrucache . && make install LUA_LIB_DIR=/usr/local/share/lua/5.1/

WORKDIR /usr/src/lua-resty-string
RUN git clone https://github.com/openresty/lua-resty-string . && make install LUA_LIB_DIR=/usr/local/share/lua/5.1

WORKDIR /usr/src/headers-more-nginx-module
RUN git clone https://github.com/openresty/headers-more-nginx-module.git .

WORKDIR /usr/src/ngx_brotli
RUN git clone https://github.com/google/ngx_brotli.git . && git submodule update --init

WORKDIR /usr/src/luajit2
RUN git clone https://github.com/openresty/luajit2 . && make install

ARG LUAJIT_INC=/usr/local/include/luajit-2.1
ARG LUAJIT_LIB=/usr/local/lib

# Prepare for Nginx compilation.

# Remove previously built Nginx modules and previous Nginx configuration.
RUN rm -f /usr/lib/nginx/modules/*
RUN rm -rf /etc/nginx/*

RUN curl "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar --gunzip --extract --directory=/usr/src
WORKDIR /usr/src/nginx-${NGINX_VERSION}

# Disable the `Server` response header and remove "nginx" from the error pages.

RUN sed -i 's@"nginx/"@"-/"@g' src/core/nginx.h \
    && sed -i 's@r->headers_out.server == NULL@0@g' src/http/ngx_http_header_filter_module.c \
    && sed -i 's@r->headers_out.server == NULL@0@g' src/http/v2/ngx_http_v2_filter_module.c \
    && sed -i -e 's@<hr><center>nginx</center>@@g' -e 's@<hr><center>" NGINX_VER "</center>@@g' -e 's@<hr><center>" NGINX_VER_BUILD "</center>@@g' src/http/ngx_http_special_response.c

# Generate error pages.

COPY ./generate_error_pages.sh .
RUN ./generate_error_pages.sh > /etc/nginx/error_pages.conf

# Configure and compile Nginx with custom arguments.

RUN ./configure \
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
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-threads \
    --with-http_ssl_module \
    --with-http_v2_module \
    --add-dynamic-module=/usr/src/lua-nginx-module \
    --add-dynamic-module=/usr/src/ngx_devel_kit \
    --add-dynamic-module=/usr/src/headers-more-nginx-module \
    --add-dynamic-module=/usr/src/ngx_brotli \
    --add-dynamic-module=/usr/src/ModSecurity-nginx \
    --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
    --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
    --with-ld-opt='-Wl,-rpath,/usr/local/lib' \
    && make install

FROM nginx:${NGINX_VERSION}

ARG MODSEC_VERSION=3.0.8

RUN rm -rf /usr/lib/nginx/modules/* /etc/nginx/* /usr/local/*

COPY --from=builder /usr/share/TLS/dhparam-* /etc/ssl/certs/
COPY --from=builder /etc/modsecurity.d/unicode.mapping /etc/modsecurity.d/unicode.mapping
COPY --from=builder /etc/modsecurity.d/modsecurity.conf /etc/modsecurity.d/modsecurity.conf

COPY --from=builder /usr/lib/nginx/modules/* /usr/lib/nginx/modules
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx/* /etc/nginx
COPY --from=builder /usr/local/ /usr/local
COPY --from=builder /usr/src/lua_modules/share/lua/5.1 /etc/nginx/lua
COPY --from=builder /usr/src/lua_modules/lib/lua/5.1/cjson.so /usr/local/lib/lua/5.1
COPY --from=builder /usr/src/lua-resty-logger-socket/lib/ /etc/nginx/lua

RUN set -eux; \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections; \
    apt-get update -qq; \
    LD_LIBRARY_PATH="" apt-get install -y -qq --no-install-recommends --no-install-suggests \
        ca-certificates \
        curl \
        libcurl4-gnutls-dev \
        libfuzzy2 \
        liblua5.3 \
        libxml2 \
        libyajl2 \
        moreutils; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get clean; \
    mkdir /etc/nginx/ssl; \
    mkdir -p /tmp/modsecurity/data; \
    mkdir -p /tmp/modsecurity/upload; \
    mkdir -p /tmp/modsecurity/tmp; \
    mkdir -p /usr/local/modsecurity; \
    chown -R nginx:nginx /tmp/modsecurity; \
    ln --symbolic --force /usr/local/modsecurity/lib/libmodsecurity.so.${MODSEC_VERSION} /usr/local/modsecurity/lib/libmodsecurity.so.3.0; \
    ln --symbolic --force /usr/local/modsecurity/lib/libmodsecurity.so.${MODSEC_VERSION} /usr/local/modsecurity/lib/libmodsecurity.so.3; \
    ln --symbolic --force /usr/local/modsecurity/lib/libmodsecurity.so.${MODSEC_VERSION} /usr/local/modsecurity/lib/libmodsecurity.so; \
    chgrp -R 0 /var/cache/nginx/ /var/log/ /var/run/ /usr/share/nginx/ /etc/nginx/ /etc/modsecurity.d/; \
    chmod -R g=u /var/cache/nginx/ /var/log/ /var/run/ /usr/share/nginx/ /etc/nginx/ /etc/modsecurity.d/;