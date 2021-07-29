FROM rust:1.53-buster as builder

RUN apt update -y \
  && apt install -y \
    build-essential \
    clang \
    gcc \
    gettext \
    gnutls-bin \
    libclang-dev \
    llvm-dev \
    nettle-dev \
    pkg-config \
  && rm -rf /var/lib/apt/lists/*

ARG HAGRID_VERSION='90356ddb282874d5be5f7406e49e203f3caf437c'

RUN git clone https://gitlab.com/hagrid-keyserver/hagrid.git /build
RUN cd /build/ \
  && git checkout "$HAGRID_VERSION" \
  && cargo build --release

FROM andrewzah/base-debian:buster-slim

COPY --from=builder /build/target/release/hagrid /usr/local/bin/hagrid
COPY --from=builder --chown=abc:abc /build/dist/ /app/dist/

# [branding] remove about for now
RUN rm -r /app/dist/templates/about
COPY ./index.html.hbs /app/dist/templates/index.html.hbs

COPY ./root/ /
EXPOSE 8080 11371
