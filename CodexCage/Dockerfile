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
    py3-pillow \
    procps

COPY vendor/codex /opt/codex

ENV PATH="/opt/codex/bin:${PATH}"
