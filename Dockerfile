ARG ARCH=amd64
ARG VERSION=2.0.6-dev
FROM robertslando/zwave2mqtt:${ARCH}-${VERSION} as upstream

# Add unprivileged user
RUN echo "zwave2mqtt:x:1000:1000:zwave2mqtt:/:" > /etc_passwd

# Remove directory used for persistance
RUN rm -rf /usr/src/app/store

# ----------------
# STEP 2:
# Run a scratch image
FROM scratch

# Copy the unprivileged user
COPY --from=builder /etc_passwd /etc/passwd

# udevadm comes from the needed eudev package
COPY --from=upstream \
  /bin/busybox \
  /bin/udevadm \
  /bin/

# Copy needed libs
# libopenzwave needs to have the version!
COPY --from=upstream \
  /lib/ld-musl-*.so.1 \
  /lib/libc.musl-*.so.1 \
  /lib/libopenzwave.so.1.* \
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
