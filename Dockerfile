FROM openresty/openresty:alpine-fat

RUN apk add --no-cache --virtual .build-deps \
 outils-md5 \
 cmake \
 &&  /usr/local/openresty/luajit/bin/luarocks install lua-resty-jwt \
 &&  /usr/local/openresty/luajit/bin/luarocks install busted \
 && apk del .build-deps

RUN mkdir /var/log/nginx

#COPY ./lugate /etc/nginx/lugate
COPY ./docker/nginx/server.conf /etc/nginx/conf.d/default.conf
COPY ./docker/nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf