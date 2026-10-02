#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_CAGE_DIR="$(dirname "$SCRIPT_DIR")"

if [ "$1" = "--login" ]; then
  CONTAINER_NAME="codex-cage-login"

  docker run --rm -dit \
    --name "$CONTAINER_NAME" \
    --security-opt=seccomp=unconfined \
    --security-opt=apparmor=unconfined \
    --mount type=bind,src="$CODEX_CAGE_DIR/workspace",dst=/workspace \
    --env CODEX_HOME=/workspace/.codex \
    --workdir /workspace \
    --publish 127.0.0.1:1455:1456 \
    codex-cage codex

  docker exec -d "$CONTAINER_NAME" \
    socat TCP-LISTEN:1456,fork,bind=0.0.0.0 TCP:127.0.0.1:1455

  docker attach "$CONTAINER_NAME"
else
  docker run --rm -it \
    --security-opt=seccomp=unconfined \
    --security-opt=apparmor=unconfined \
    --mount type=bind,src="$CODEX_CAGE_DIR/workspace",dst=/workspace \
    --env CODEX_HOME=/workspace/.codex \
    --workdir /workspace \
    codex-cage codex
fi