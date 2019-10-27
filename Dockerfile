FROM alpine:3.10 as builder

ARG VERSION=master

LABEL maintainer="wilmardo" \
  description="zwave2mqtt from scratch"

RUN addgroup -S -g 1000 zwave2mqtt 2>/dev/null && \
  adduser -S -u 1000 -D -H -h /dev/shm -s /sbin/nologin -G zwave2mqtt -g zwave2mqtt zwave2mqtt 2>/dev/null && \
  addgroup zwave2mqtt dialout

# Install required dependencies
RUN apk --no-cache add \
    git \
    python \
    make \
    build-base \
    linux-headers \
    eudev-dev \
    libusb-dev \
    coreutils \
    npm \
    upx

# # Install required dependencies
# RUN apk update && apk --no-cache add \
#       gnutls \
#       gnutls-dev \
#       libusb \
#       eudev \
#       # Install build dependencies
#     && apk --no-cache --virtual .build-deps add \
#       coreutils \
#       eudev-dev \
#       build-base \
#       git \
#       python \
#       bash \
#       libusb-dev \
#       linux-headers \
#       wget \
#       tar  \
#       openssl \
#       make 


RUN git clone --depth 1 --single-branch --branch ${VERSION} https://github.com/OpenZWave/Zwave2Mqtt.git /zwave2mqtt
RUN git clone --depth 1 --single-branch --branch master https://github.com/OpenZWave/open-zwave.git /open-zwave
ADD http://old.openzwave.com/downloads/openzwave-1.4.1.tar.gz /

# Makeflags source: https://math-linux.com/linux/tip-of-the-day/article/speedup-gnu-make-build-and-compilation-process
RUN CORES=$(grep -c '^processor' /proc/cpuinfo); \
    export MAKEFLAGS="-j$((CORES+1)) -l${CORES}"; \
    tar zxvf openzwave-*.gz \
    && cd openzwave-* && make && make install \
    && mkdir -p /dist/lib \
    && mv libopenzwave.so* /usr/lib

WORKDIR /zwave2mqtt

# NOTE(wilmardo): --build is needed for dynamic require that serialport/bindings seems to use
# NOTE(wilmardo): For the upx steps and why --empty see: https://github.com/nexe/nexe/issues/366
RUN CORES=$(grep -c '^processor' /proc/cpuinfo); \
  export MAKEFLAGS="-j$((CORES+1)) -l${CORES}"; \
  npm install --unsafe-perm && \
  npm install --unsafe-perm --global nexe && \
  nexe \
  --build \
  --empty \
  --output zwave2mqtt app.js && \
  upx --best /root/.nexe/*/out/Release/node && \
  nexe \
  --build \
  --output zwave2mqtt app.js

FROM alpine:latest

# LABEL maintainer="robertsLando"

# udevadm binary is used by zwave2mqtt
COPY --from=builder \
  /bin/udevadm \
  /bin/

# Copy users from builder
COPY --from=builder \
  /etc/passwd \
  /etc/group \
  /etc/

# Copy needed libs
COPY --from=builder \
  /lib/ld-musl-*.so.1 \
  /lib/libc.musl-*.so.1 \
  /lib/
COPY --from=builder \
  /usr/lib/libstdc++.so.6 \
  /usr/lib/libgcc_s.so.1 \
  /usr/lib/

# Copy config for openzwaves    

# Copy zwave2mqtt binary and stupid dynamic @serialport
COPY --from=builder /zwave2mqtt/zwave2mqtt /zwave2mqtt/zwave2mqtt
# COPY --from=builder \
#   /zwave2mqtt/node_modules/zigbee-herdsman/node_modules/@serialport/bindings/ \
#   /zwave2mqtt/node_modules/zigbee-herdsman/node_modules/@serialport/bindings/

# # Adds entrypoint
# COPY ./entrypoint.sh /entrypoint.sh

USER zwave2mqtt
WORKDIR /zwave2mqtt
ENTRYPOINT ["./zwave2mqtt" ]
