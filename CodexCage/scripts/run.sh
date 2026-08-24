#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_CAGE_DIR="$(dirname "$SCRIPT_DIR")"

docker run --rm -it \
  --security-opt=seccomp=unconfined \
  --security-opt=apparmor=unconfined \
  --mount type=bind,src="$CODEX_CAGE_DIR/workspace",dst=/workspace \
  --env CODEX_HOME=/workspace/.codex \
  --workdir /workspace \
  codex-cage sh