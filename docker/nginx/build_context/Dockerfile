# syntax=docker/dockerfile:experimental
ARG NGINX_VERSION

FROM nginx:${NGINX_VERSION} as builder

ARG NGINX_VERSION

RUN apt-get update && \
    apt-get install -y \
        openssh-client \
        git \
        wget \
        libxml2 \
        libxslt1-dev \
        libpcre3 \
        libpcre3-dev \
        zlib1g \
        zlib1g-dev \
        openssl \
        libssl-dev \
        libtool \
        automake \
        gcc \
        g++ \
        make \
        lua5.1 \
        liblua5.1-dev \
        unzip \
    && rm -rf /var/cache/apt

RUN wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
    tar -C /usr/src -xzvf nginx-${NGINX_VERSION}.tar.gz

WORKDIR /usr/src/lua-nginx-module
RUN git clone https://github.com/openresty/lua-nginx-module .

WORKDIR /usr/src/ngx_devel_kit
RUN git clone https://github.com/vision5/ngx_devel_kit .

WORKDIR /usr/src/lua-resty-logger-socket
RUN git clone https://github.com/cloudflare/lua-resty-logger-socket .

# Install Lua modules.

# NOTE: Apperently the LuaRocks version that can be installed via `apt` is old and does not support some package
# format used by one of the LuaRocks packages, so LuaRocks has to be installed separately...
RUN wget "https://luarocks.org/releases/luarocks-3.8.0.tar.gz" && tar -C /usr/src -zxpf luarocks-3.8.0.tar.gz
WORKDIR /usr/src/luarocks-3.8.0
RUN ./configure --with-lua-include=/usr/include/lua5.1 && make install

WORKDIR /usr/src/lua_modules
RUN luarocks install base64 --tree . \
    && luarocks install lua-cjson --tree . \
    && rm -rf /usr/share/lua/5.1/luarocks

WORKDIR /usr/src/lua-resty-core
RUN git clone https://github.com/openresty/lua-resty-core . && make install  LUA_LIB_DIR=/usr/local/share/lua/5.1/

WORKDIR /usr/src/lua-resty-lrucache
RUN git clone https://github.com/openresty/lua-resty-lrucache . && make install LUA_LIB_DIR=/usr/local/share/lua/5.1/

WORKDIR /usr/src/lua-resty-string
RUN git clone https://github.com/openresty/lua-resty-string . && make install LUA_LIB_DIR=/usr/local/share/lua/5.1

WORKDIR /usr/src/headers-more-nginx-module
RUN git clone https://github.com/openresty/headers-more-nginx-module.git .

WORKDIR /usr/src/ngx_brotli
RUN git clone https://github.com/google/ngx_brotli.git . && git submodule update --init

# Remove previously built Nginx modules and previous Nginx configuration.

RUN rm -f /usr/lib/nginx/modules/*
RUN rm -rf /etc/nginx/*

# Prepare for Nginx compilation.

WORKDIR /usr/src/luajit2
RUN git clone https://github.com/openresty/luajit2 . && make install

ARG LUAJIT_INC=/usr/local/include/luajit-2.1
ARG LUAJIT_LIB=/usr/local/lib

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
    --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
    --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
    --with-ld-opt='-Wl,-rpath,/usr/local/lib' \
    && make install

FROM nginx:${NGINX_VERSION}

RUN rm -rf /usr/lib/nginx/modules/* /etc/nginx/* /usr/local/*

COPY --from=builder /usr/lib/nginx/modules/* /usr/lib/nginx/modules
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx/* /etc/nginx
COPY --from=builder /usr/local/ /usr/local
COPY --from=builder /usr/src/lua_modules/share/lua/5.1 /etc/nginx/lua
COPY --from=builder /usr/src/lua_modules/lib/lua/5.1/cjson.so /usr/local/lib/lua/5.1
COPY --from=builder /usr/src/lua-resty-logger-socket/lib/ /etc/nginx/lua
