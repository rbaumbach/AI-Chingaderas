# AI-Junk

A repo with random AI junk

## CodexCage

A Docker sandbox for running Codex CLI with controlled filesystem access.

The goal of CodexCage is simple:

> Give Codex access to the code it needs to modify, while keeping the rest of the machine outside the cage.

Codex has internet access so it can communicate with OpenAI services, but the container only receives explicit access to directories that are mounted into it.

### Requirements

TODO: List ruby installation instructions

### Install instructions

Initial install requires downloading Codex:

```zsh
ruby CodexCage/scripts/download_codex.rb
```

Then we build the image and then create the container:

```zsh
docker build -f CodexCage/Dockerfile -t codex-cage CodexCage

docker run --rm -it \
  --mount type=bind,src="$PWD/CodexCage/workspace",dst=/workspace \
  --workdir /workspace \
  codex-cage sh
```

Note: Once the image is built, you can take advantage of the `run.sh` script:

```zsh
CodexCage/scripts/run.sh
```
