# ----------------
# STEP 1:
# https://lobradov.github.io/Building-docker-multiarch-images/
# Build Openzwave and Zwave2Mqtt pkg
# All result files will be put in /dist folder
FROM node:carbon-alpine AS build

# Set the commit of Zwave2Mqtt to checkout when cloning the repo
ENV Z2M_VERSION=fd2aa6e67bb7c4bee75babd83fc1b5369145b6bf

# Install required dependencies
RUN apk update && apk --no-cache add \
      gnutls \
      gnutls-dev \
      libusb \
      eudev \
      # Install build dependencies
    && apk --no-cache --virtual .build-deps add \
      coreutils \
      eudev-dev \
      build-base \
      git \
      python \
      bash \
      libusb-dev \
      linux-headers \
      wget \
      tar  \
      openssl \
      make 

# Clone 1.4 branch and move binaries in /dist/lib and devices db on /dist/db
RUN cd /root \
    && git clone -b 1.4 https://github.com/OpenZWave/open-zwave.git \
    && cd open-zwave && make && make install \
    && mkdir -p /dist/lib \
    && mv libopenzwave.so* /dist/lib/ \
    && mkdir -p /dist/db \
    && mv config/* /dist/db

COPY bin/package.sh /root/package.sh

# Clone Zwave2Mqtt build pkg files and move them to /dist/pkg
RUN npm config set unsafe-perm true && npm install -g pkg@4.3.8 \
    && cd /root \
    && git clone https://github.com/OpenZWave/Zwave2Mqtt.git  \
    && cd Zwave2Mqtt \
    && git checkout ${Z2M_VERSION} \
    && npm install \
    && npm run build

RUN cd /root \
    && chmod +x package.sh && ./package.sh \
    && mkdir -p /dist/pkg \
    && mv /root/Zwave2Mqtt/pkg/* /dist/pkg

# Clean up
RUN rm -R /root/* && apk del .build-deps

# ----------------
# STEP 2:
# Run a minimal alpine image
FROM alpine:latest

LABEL maintainer="robertsLando"

RUN apk update && apk add --no-cache \
    libstdc++  \
    libgcc \
    libusb \
    tzdata \
    eudev 

# Copy files from previous build stage
COPY --from=build /dist/lib/ /lib/
COPY --from=build /dist/db/ /usr/local/etc/openzwave/ 
COPY --from=build /dist/pkg /usr/src/app

# Set enviroment
ENV LD_LIBRARY_PATH /lib

WORKDIR /usr/src/app

EXPOSE 8091

# Override default alpine entrypoint
ENTRYPOINT [""]

CMD ["/usr/src/app/zwave2mqtt"]