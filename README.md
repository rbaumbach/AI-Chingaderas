# AI-Junk

A repo with random AI junk.

## CodexCage

A lightweight Docker sandbox for running Codex CLI with controlled filesystem access.

### Requirements

- macOS on Apple Silicon
- Docker Desktop
- Ruby

TODO: Add Ruby installation instructions.

### Initial install

Download the latest standalone ARM64 Linux Codex binary using the included Ruby script:

```zsh
ruby CodexCage/scripts/download_codex.rb
```

Then build the Docker image:

```zsh
docker build -f CodexCage/Dockerfile -t codex-cage CodexCage
```

### Running CodexCage

Use the provided run script:

```zsh
CodexCage/scripts/run.sh
```

The script starts a disposable container with:

- `CodexCage/workspace` mounted read/write at `/workspace`;
- `/workspace` as the working directory;
- `CODEX_HOME` set to `/workspace/.codex`;
- an interactive Alpine shell.

Once inside the container, run `codex` in the shell to begin.

Note: 

Codex has normal internet access so it can communicate with OpenAI services, but the container only receives access to host directories that are explicitly mounted into it.

The container is disposable and runs with `--rm`. The workspace is bind-mounted from the host, so files inside the workspace persist after the container exits.

### Codex login

After completing the browser/device-code login inside the shell, Codex stores its authentication state under `CodexCage/workspace/.codex`. Since we use `/workspace/.codex` as it's `CODEX_HOME`, future containers reuse that state, so repeated login should not normally be necessary.

### Updating Codex

To update the Codex binary use the included Ruby script:

```zsh
ruby CodexCage/scripts/update_codex.rb
```

The existing Codex binary is therefore left untouched if downloading, verification, or extraction fails.  After updating Codex, rebuild the Docker image:

```zsh
docker build -f CodexCage/Dockerfile -t codex-cage CodexCage
```

The Dockerfile copies the current binary into the image:

```dockerfile
COPY vendor/codex /usr/local/bin/codex
```

The next CodexCage container will then use the updated version.

You can verify the version baked into the image with:

```zsh
docker run --rm codex-cage codex --version
```

### Workspace

Only files placed inside the `workspace` are intentionally exposed to the container.

The cage is intentionally simple. Keep the mounted filesystem surface small and only give Codex the code it actually needs.
