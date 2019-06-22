FROM openresty/openresty:alpine-fat

COPY . /etc/nginx/prizm-build

RUN apk add --no-cache --virtual .build-deps \
 outils-md5 \
 cmake \
 &&  /usr/local/openresty/luajit/bin/luarocks install lua-resty-jwt \
 && cd /etc/nginx/prizm-build \
 && /usr/local/openresty/luajit/bin/luarocks  make \
 && rm -rf /etc/nginx/prizm-build \
 && apk del .build-deps

RUN mkdir /var/log/nginx

COPY ./docker/nginx/main.lua  /etc/nginx/prizm/main.lua
COPY ./docker/nginx/server.conf /etc/nginx/conf.d/default.conf
COPY ./docker/nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf