FROM alpine:3.6
# Update apk index.
RUN apk update

RUN apk add --no-cache nginx-mod-http-lua lua-dev git bash unzip build-base  curl cmake openssl

# Build Luarocks.
RUN cd /tmp && \
    git clone https://github.com/keplerproject/luarocks.git --branch v3.0.4 --single-branch && \
    cd luarocks && \
    sh ./configure && \
    make build install && \
    cd && \
rm -rf /tmp/luarocks && \
rm -rf ~/.cache/luarocks

# Delete default config
#RUN rm -r /etc/nginx/conf.d && rm /etc/nginx/nginx.conf
#RUN /usr/local/bin/luarocks install tmp
RUN /usr/local/bin/luarocks install rapidjson
RUN /usr/local/bin/luarocks install redis-lua

COPY ./docker/nginx/lugate /etc/nginx/lugate
COPY ./docker/nginx/lugate.lua /etc/nginx/lugate.lua
#COPY ./docker/nginx/tmp /tmp/tmp
#RUN /usr/local/bin/luarocks install /tmp/tmp/tmp-0.6.1-1.rockspec

# Create folder for PID file
RUN mkdir -p /run/nginx

# Add our nginx conf
COPY ./docker/nginx/server.conf /etc/nginx/conf.d/nginx.conf
COPY ./docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/nginx/gate.lua /etc/nginx/gate.lua

CMD ["nginx"]