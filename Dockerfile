ARG ARCHITECTURE
#######################################################################################################################
# Openzwave build
#######################################################################################################################
FROM multiarch/alpine:${ARCHITECTURE}-v3.11 as openzwave-builder

# See old.openzwave.com/downloads/ for latest
ENV VERSION=1.6.1123

# coreutils: needed for openzwave compile
RUN apk --no-cache add \
  build-base \
  coreutils

# Setup OpenZwave
RUN mkdir /openzwave && \
  wget -qO- http://old.openzwave.com/downloads/openzwave-${VERSION}.tar.gz \
  | tar -xvzf - -C openzwave --strip-components=1

WORKDIR /openzwave

# Makeflags source: https://math-linux.com/linux/tip-of-the-day/article/speedup-gnu-make-build-and-compilation-process
# Compile openzwave definitions and library
RUN CORES=$(grep -c '^processor' /proc/cpuinfo); \
  export MAKEFLAGS="-j$((CORES+1)) -l${CORES}"; \
  make install


#######################################################################################################################
# Nexe packaging of binary
#######################################################################################################################
FROM lansible/nexe:4.0.0-beta.6-${ARCHITECTURE} as builder

ENV VERSION=3.2.0

# Add unprivileged user
RUN echo "zwave2mqtt:x:1000:1000:zwave2mqtt:/:" > /etc_passwd
# Add to dailout as secondary group (20)
RUN echo "dailout:x:20:zwave2mqtt" > /etc_group

# eudev: needed for udevadm binary
RUN apk --no-cache add \
  eudev

# Setup Zwave2Mqtt
RUN git clone --depth 1 --single-branch --branch v${VERSION} https://github.com/OpenZWave/Zwave2Mqtt.git /zwave2mqtt

WORKDIR /zwave2mqtt

# Apply stateless patch
COPY stateless.patch /zwave2mqtt/stateless.patch
RUN git apply stateless.patch

# Adds openzwave header files for the building of openzwave-shared
COPY --from=openzwave-builder /usr/local/include/openzwave /usr/local/include/openzwave

# Adds openzwave library
# libopenzwave needs to have the .1 version!
COPY --from=openzwave-builder \
  /usr/local/lib/libopenzwave.so \
  /usr/local/lib/libopenzwave.so

# Install all modules
# Force build of openzwave-shared, otherwise seems to skip the .node addon compilation
# Run build to make all html files
RUN CORES=$(grep -c '^processor' /proc/cpuinfo); \
  export MAKEFLAGS="-j$((CORES+1)) -l${CORES}"; \
  npm install && \
  npm build node_modules/openzwave-shared/ && \
  npm run build

# Package the binary
# Create /data to copy into final stage
RUN nexe --build --target alpine \
  --resource lib/ \
  --resource config/ \
  --resource hass/ \
  --resource dist/ \
  --resource node_modules/socket.io-client/dist/socket.io.js \
  --resource app.js \
  --output zwave2mqtt bin/www && \
  mkdir /data /config


#######################################################################################################################
# Final scratch image
#######################################################################################################################
FROM scratch

# Set env vars for persitance
ENV ZWAVE2MQTT_CONFIG=/config/settings.json \
    ZWAVE2MQTT_DATA=/data

# Add description
LABEL org.label-schema.description="Zwave2MQTT as single binary in a scratch container"

# Copy the unprivileged user
COPY --from=builder /etc_passwd /etc/passwd
COPY --from=builder /etc_group /etc/group

# Serialport is using the udevadm binary
COPY --from=builder /bin/udevadm /bin/udevadm

# Copy needed libs(libstdc++.so, libgcc_s.so) for nodejs since it is partially static
# Copy linker to be able to use them (lib/ld-musl)
# Can't be fullly static since @serialport uses a C++ node addon
# https://github.com/serialport/node-serialport/blob/master/packages/bindings/lib/linux.js#L2
COPY --from=builder /lib/ld-musl-*.so.1 /lib/
COPY --from=builder \
  /usr/lib/libstdc++.so.6 \
  /usr/lib/libgcc_s.so.1 \
  /usr/lib/

# Adds openzwave library
# libopenzwave needs to have the .1.* version!
COPY --from=openzwave-builder \
  /usr/local/lib/libopenzwave.so.1.* \
  /lib/

# Copy zwave2mqtt binary
COPY --from=builder /zwave2mqtt/zwave2mqtt /zwave2mqtt/zwave2mqtt

# Copy openzwave definitions (location defined in settings.json)
COPY --from=openzwave-builder /usr/local/etc/openzwave/ /usr/local/etc/openzwave/

# Add bindings.node for serialport
COPY --from=builder \
  /zwave2mqtt/node_modules/@serialport/bindings/build/Release/bindings.node \
  /zwave2mqtt/build/bindings.node

# Add openzwave-shared module
COPY --from=builder \
  /zwave2mqtt/node_modules/openzwave-shared/build/Release/openzwave_shared.node \
  /zwave2mqtt/node_modules/openzwave-shared/build/Release/openzwave_shared.node

# Create default data directory
# Will fail at runtime due missing the mkdir binary
COPY --from=builder --chown=zwave2mqtt:0 /data /data
COPY --from=builder --chown=zwave2mqtt:0 /config /config

EXPOSE 8091
USER zwave2mqtt
WORKDIR /zwave2mqtt
ENTRYPOINT ["./zwave2mqtt"]
