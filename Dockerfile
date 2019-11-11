FROM robertslando/zwave2mqtt:latest as upstream

ARG VERSION=master

RUN addgroup -S -g 1000 zwave2mqtt 2>/dev/null && \
  adduser -S -u 1000 -D -H -h /dev/shm -s /sbin/nologin -G zwave2mqtt -g zwave2mqtt zwave2mqtt 2>/dev/null && \
  addgroup zwave2mqtt dialout

# Remove directory used for persistance
RUN rm -rf /usr/src/app/store

# ----------------
# STEP 2:
# Run a scratch image
FROM scratch

# Copy users from upstream
COPY --from=upstream \
  /etc/passwd \
  /etc/group \
  /etc/

# udevadm comes from the needed eudev package
COPY --from=upstream \
  /bin/busybox \
  /bin/udevadm \
  /bin/

# Copy needed libs
COPY --from=upstream \
  /lib/ld-musl-*.so.1 \
  /lib/libc.musl-*.so.1 \
  /lib/libopenzwave.so.1.4 \
  /lib/libudev.so.1 \
  /lib/
COPY --from=upstream \
  /usr/lib/libstdc++.so.6 \
  /usr/lib/libgcc_s.so.1 \
  /usr/lib/

# Copy files from upstream
COPY --from=upstream /usr/local/etc/openzwave/ /usr/local/etc/openzwave/ 
COPY --from=upstream /usr/src/app /usr/src/app

# Create symlink for persistance
RUN ["/bin/busybox", "ln", "-sf", "/data", "/usr/src/app/store"]

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh

USER zwave2mqtt
ENTRYPOINT ["/bin/busybox", "ash", "/entrypoint.sh" ]
WORKDIR /usr/src/app
CMD ["/usr/src/app/zwave2mqtt"]
EXPOSE 8091
