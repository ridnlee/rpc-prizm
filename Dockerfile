FROM openresty/openresty:alpine-fat

RUN apk add --no-cache --virtual .build-deps \
 outils-md5 \
 cmake \
 &&  /usr/local/openresty/luajit/bin/luarocks install lua-resty-jwt \
 && apk del .build-deps

RUN mkdir /var/log/nginx

COPY ./docker/nginx/lugate /etc/nginx/lugate
COPY ./docker/nginx/server.conf /etc/nginx/conf.d/default.conf
COPY ./docker/nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY ./docker/nginx/gate.lua /etc/nginx/gate.lua