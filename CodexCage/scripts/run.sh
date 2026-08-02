#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_CAGE_DIR="$(dirname "$SCRIPT_DIR")"

docker run --rm -it \
  --mount type=bind,src="$CODEX_CAGE_DIR/workspace",dst=/workspace \
  --workdir /workspace \
  codex-cage sh
