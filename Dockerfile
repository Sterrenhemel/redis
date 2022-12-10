FROM alpine:3.15 as builder1

MAINTAINER Opstree Solutions

LABEL VERSION=1.0 \
      ARCH=AMD64 \
      DESCRIPTION="A production grade performance tuned redis docker image created by Opstree Solutions"

ARG REDIS_DOWNLOAD_URL="http://download.redis.io/"

ARG REDIS_VERSION="stable"

RUN apk add --no-cache su-exec tzdata cmake make curl build-base linux-headers bash openssl-dev

RUN curl -fL -Lo /tmp/redis-${REDIS_VERSION}.tar.gz ${REDIS_DOWNLOAD_URL}/redis-${REDIS_VERSION}.tar.gz && \
    cd /tmp && \
    tar xvzf redis-${REDIS_VERSION}.tar.gz && \
    cd redis-${REDIS_VERSION} && \
    make && \
    make install BUILD_TLS=yes

#----------------------------------------------------------------------------------------------
FROM redisfab/redis:7.0.5-x64-bullseye AS builder2

#ARG REDIS_VER=7.0.5

# ARCH=x64|arm64v8|arm32v7
#ARG ARCH=x64

RUN apt-get update -qq && apt-get install -y git

RUN git clone --recursive https://github.com/RedisBloom/RedisBloom.git /app/redis-bloom

# RUN git clone --recursive https://github.com/alibaba/TairZset.git /app/tair-zset

# RUN git clone --recursive https://github.com/alibaba/TairHash /app/tair-hash

# RUN git clone --recursive https://github.com/alibaba/TairString /app/tair-string


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

WORKDIR /app/tair-zset

# /app/tair-zset/lib/tairzset_module.so
RUN mkdir build && cd build && cmake ../ && make -j


WORKDIR /app/tair-hash

# /app/tair-hash/lib/tairhash_module.so
RUN mkdir build && cd build && cmake ../ && make -j

# WORKDIR /app/tair-string

# # /app/tair-string/lib/tairstring_module.so
# RUN mkdir build && cd build && cmake ../ && make -j

FROM alpine:3.15

MAINTAINER Opstree Solutions

LABEL VERSION=1.0 \
      ARCH=AMD64 \
      DESCRIPTION="A production grade performance tuned redis docker image created by Opstree Solutions"

COPY --from=builder1 /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder1 /usr/local/bin/redis-cli /usr/local/bin/redis-cli
COPY --from=builder2 /app/redis-bloom/bin/linux-x64-release/redisbloom.so /usr/local/lib/redis/modules/redisbloom.so
# COPY --from=builder2 /app/tair-zset/lib/tairzset_module.so /usr/local/lib/redis/modules/tairzset_module.so
# COPY --from=builder2 /app/tair-hash/lib/tairhash_module.so /usr/local/lib/redis/modules/tairhash_module.so
# COPY --from=builder2 /app/tair-string/lib/tairstring_module.so /usr/local/lib/redis/modules/tairstring_module.so

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
