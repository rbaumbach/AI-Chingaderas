# Alpine releases:
# https://alpinelinux.org/releases/

FROM alpine:3.24

RUN apk add --no-cache \
    bash \
    git \
    ripgrep \
    ca-certificates \
    tar \
    bubblewrap \
    ruby \
    python3 \
    py3-pillow

WORKDIR /tmp/codex-install

COPY vendor/codex /usr/local/bin/codex
COPY vendor/codex-code-mode-host /usr/local/bin/codex-code-mode-host
