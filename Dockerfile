FROM alpine:3.15 as builder1

MAINTAINER Opstree Solutions

LABEL VERSION=1.0 \
      ARCH=AMD64 \
      DESCRIPTION="A production grade performance tuned redis docker image created by Opstree Solutions"

ARG REDIS_DOWNLOAD_URL="http://download.redis.io/"

ARG REDIS_VERSION="stable"

RUN apk add --no-cache su-exec tzdata make curl build-base linux-headers bash openssl-dev

RUN curl -fL -Lo /tmp/redis-${REDIS_VERSION}.tar.gz ${REDIS_DOWNLOAD_URL}/redis-${REDIS_VERSION}.tar.gz && \
    cd /tmp && \
    tar xvzf redis-${REDIS_VERSION}.tar.gz && \
    cd redis-${REDIS_VERSION} && \
    make && \
    make install BUILD_TLS=yes

#----------------------------------------------------------------------------------------------
FROM redisfab/redis:${REDIS_VER}-${ARCH}-${OSNICK} AS builder2

ARG REDIS_VER=7.0.5

# stretch|bionic|buster
ARG OSNICK=bullseye

# ARCH=x64|arm64v8|arm32v7
ARG ARCH=x64

RUN apt-get update -qq && apt-get install -y git

RUN git clone --recursive https://github.com/RedisBloom/RedisBloom.git /app/redis-bloom

WORKDIR /app/redis-bloom

RUN ./deps/readies/bin/getupdates
RUN ./sbin/setup
RUN set -ex ;\
    if [ -e /usr/bin/apt-get ]; then \
        apt-get update -qq; \
        apt-get upgrade -yqq; \
        rm -rf /var/cache/apt; \
    fi

# RUN bash -l -c "make fetch"
RUN bash -l -c "make all"
# /app/redis-bloom/bin/linux-x64-release/redisbloom.so

FROM alpine:3.15

MAINTAINER Opstree Solutions

LABEL VERSION=1.0 \
      ARCH=AMD64 \
      DESCRIPTION="A production grade performance tuned redis docker image created by Opstree Solutions"

COPY --from=builder1 /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder1 /usr/local/bin/redis-cli /usr/local/bin/redis-cli
COPY --from=builder2 /app/redis-bloom/bin/linux-x64-release/redisbloom.so /usr/local/lib/redis/modules/redisbloom.so

RUN addgroup -S -g 1000 redis && adduser -S -G redis -u 1000 redis && \
    apk add --no-cache bash

COPY redis.conf /etc/redis/redis.conf

COPY entrypoint.sh /usr/bin/entrypoint.sh

COPY setupMasterSlave.sh /usr/bin/setupMasterSlave.sh

COPY healthcheck.sh /usr/bin/healthcheck.sh

RUN chown -R redis:redis /etc/redis

VOLUME ["/data"]

WORKDIR /data

EXPOSE 6379

USER 1000

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
