FROM rust as builder
MAINTAINER Jens Dorfmueller

RUN apt update -y \
  && apt install -y --no-install-recommends \
    nettle-dev \
    libclang-dev \
    gettext \
  && rm -rf /var/lib/apt/lists/*

RUN git clone https://gitlab.com/hagrid-keyserver/hagrid.git /build
RUN cd /build/ \
  && cargo build --release

FROM debian:bullseye-slim

RUN apt update -y \
  && apt install -y --no-install-recommends \
    xz-utils \
    dialog \
    ssmtp

# add S6 overlays
ARG OVERLAY_VERSION="v3.1.2.1"
ARG OVERLAY_ARCH="x86_64"
ADD https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-${OVERLAY_ARCH}.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz
RUN rm -rf /tmp/*

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

COPY --from=builder /build/target/release/hagrid /usr/local/bin/hagrid
COPY --from=builder --chown=abc:abc /build/dist/ /app/dist/

# [branding] remove about for now
RUN rm -r /app/dist/templates/about
COPY ./index.html.hbs /app/dist/templates/index.html.hbs
COPY ./root/ /

ENTRYPOINT [ "/init" ]
EXPOSE 8080
