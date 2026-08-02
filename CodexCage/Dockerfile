# Alpine releases:
# https://alpinelinux.org/releases/

FROM alpine:3.24

RUN apk add --no-cache \
    ruby \
    bash \
    git \
    ripgrep \
    ca-certificates \
    tar

WORKDIR /tmp/codex-install

COPY vendor/codex /usr/local/bin/codex

