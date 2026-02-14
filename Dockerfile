# xx provides cross-compilation helpers (xx-apt-get, xx-cargo, xx-verify)
FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.9.0 AS xx

# Builder runs natively on the build platform and cross-compiles via clang/lld
FROM --platform=$BUILDPLATFORM rust:slim-bookworm AS builder
COPY --from=xx / /
LABEL org.opencontainers.image.authors="Jens Dorfmueller"

# Install native build tools (run on build platform)
# Using rust:slim-bookworm instead of rust:bookworm to avoid pre-installed
# amd64 -dev packages from buildpack-deps that conflict with arm64 multiarch.
RUN apt-get update && apt-get install -y --no-install-recommends \
    clang \
    lld \
    make \
    pkg-config \
    llvm-dev \
    libclang-dev \
    gettext \
    git \
    ca-certificates

ARG TARGETPLATFORM

# Install target-architecture libraries
# xx-apt-get handles dpkg --add-architecture and apt source configuration automatically
RUN xx-apt-get install -y --no-install-recommends \
    libc6-dev \
    nettle-dev \
    libgmp-dev \
    libssl-dev

RUN git clone --branch v2.1.0 --depth 1 https://gitlab.com/hagrid-keyserver/hagrid.git /build

# Build hagrid for the target architecture
# xx-cargo sets CC, PKG_CONFIG, CARGO_TARGET_*_LINKER, and calls rustup target add automatically
WORKDIR /build
RUN xx-cargo build --release \
    && xx-verify target/$(xx-cargo --print-target-triple)/release/hagrid \
    && cp target/$(xx-cargo --print-target-triple)/release/hagrid /usr/local/bin/hagrid

FROM debian:stable-slim

# Disable HTTP pipelining and add retries to fix apt under QEMU emulation
RUN echo 'Acquire::http::Pipeline-Depth "0";' > /etc/apt/apt.conf.d/99qemu-fix \
  && echo 'Acquire::Retries "3";' >> /etc/apt/apt.conf.d/99qemu-fix \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends \
    xz-utils \
    ca-certificates \
    wget \
    msmtp msmtp-mta \
  && rm -rf /var/lib/apt/lists/*

# add S6 overlays (with checksum verification)
ARG OVERLAY_VERSION="v3.2.1.0"
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
      arm64)  OVERLAY_ARCH=aarch64; \
              ARCH_SHA256=c8fd6b1f0380d399422fc986a1e6799f6a287e2cfa24813ad0b6a4fb4fa755cc ;; \
      *)      OVERLAY_ARCH=x86_64; \
              ARCH_SHA256=8bcbc2cada58426f976b159dcc4e06cbb1454d5f39252b3bb0c778ccf71c9435 ;; \
    esac; \
    NOARCH_SHA256=42e038a9a00fc0fef70bf0bc42f625a9c14f8ecdfe77d4ad93281edf717e10c5; \
    SYM_NOARCH_SHA256=5c0a28acc0aca6c86d90c9cd752361e0b69b0d57789064fbc8b066b2e21264d4; \
    SYM_ARCH_SHA256=c99a8c5747866aedf268067c2dadd755863044c4df76429314f5f0434200c9d5; \
    BASE_URL="https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}"; \
    cd /tmp; \
    # download all archives
    wget -q "${BASE_URL}/s6-overlay-noarch.tar.xz"; \
    wget -q "${BASE_URL}/s6-overlay-${OVERLAY_ARCH}.tar.xz"; \
    wget -q "${BASE_URL}/s6-overlay-symlinks-noarch.tar.xz"; \
    wget -q "${BASE_URL}/s6-overlay-symlinks-arch.tar.xz"; \
    # verify checksums
    echo "${NOARCH_SHA256}  s6-overlay-noarch.tar.xz" | sha256sum -c -; \
    echo "${ARCH_SHA256}  s6-overlay-${OVERLAY_ARCH}.tar.xz" | sha256sum -c -; \
    echo "${SYM_NOARCH_SHA256}  s6-overlay-symlinks-noarch.tar.xz" | sha256sum -c -; \
    echo "${SYM_ARCH_SHA256}  s6-overlay-symlinks-arch.tar.xz" | sha256sum -c -; \
    # extract
    tar -C / -Jxpf s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf "s6-overlay-${OVERLAY_ARCH}.tar.xz"; \
    tar -C / -Jxpf s6-overlay-symlinks-noarch.tar.xz; \
    tar -C / -Jxpf s6-overlay-symlinks-arch.tar.xz; \
    rm -rf /tmp/*

RUN groupadd abc \
  && groupmod -g 1000 abc \
  && useradd \
    -u 1000 \
    -g 1000 \
    -d /home/abc \
    -s /bin/sh abc \
  && usermod -G abc abc \
  && mkdir -p /app /default /home/abc \
  && chown -R abc:abc /app /default /home/abc

COPY --from=builder /usr/local/bin/hagrid /usr/local/bin/hagrid
COPY --from=builder --chown=abc:abc /build/dist/ /app/dist/

# [branding] remove about for now
RUN rm -r /app/dist/templates/about
COPY ./index.html.hbs /app/dist/templates/index.html.hbs
COPY ./root/ /

ENTRYPOINT [ "/init" ]
EXPOSE 8080
