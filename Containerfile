ARG ALPINE_VERSION=3.24

# Builder stage only exists to fetch and signature-verify the brush apk via
# apk-tools. brush is a static-pie musl binary (no libc.so, no interpreter,
# no NEEDED entries - `apk add` here doesn't even need network beyond the
# wget, since installing a local .apk file doesn't touch a repo index), so
# nothing from Alpine userland is needed at runtime and none of it makes it
# into the final image.
FROM alpine:${ALPINE_VERSION} AS builder

# Must match a tag published by release.yml (git tag vX.Y.Z) and the
# pkgrel abuild built it with (see build-apk.yml, default pkgrel: 0)
ARG BRUSH_VERSION=0.4.0
ARG BRUSH_PKGREL=0

COPY keys/apk-releases.rsa.pub /etc/apk/keys/apk-releases.rsa.pub

ARG TARGETARCH
RUN case "${TARGETARCH}" in \
      amd64) APK_ARCH=x86_64 ;; \
      arm64) APK_ARCH=aarch64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && wget -qO /tmp/brush.apk \
         "https://github.com/bbusse/alpine-brush-build/releases/download/v${BRUSH_VERSION}/${APK_ARCH}-brush-${BRUSH_VERSION}-r${BRUSH_PKGREL}.apk" \
    && apk add --no-cache /tmp/brush.apk \
    && rm /tmp/brush.apk

# Final image contains nothing but the static brush binary.
FROM scratch
LABEL maintainer="Björn Busse <bj.rn@baerlin.eu>"
LABEL org.opencontainers.image.source=https://github.com/bbusse/alpine-brush-build
LABEL org.opencontainers.image.description="brush, a bash/POSIX-compatible shell written in Rust, statically linked against musl - no OS around it"

COPY --from=builder /usr/bin/brush /brush

ENTRYPOINT ["/brush"]
