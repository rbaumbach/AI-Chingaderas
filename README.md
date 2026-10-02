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

Download and install the latest packaged ARM64 Linux Codex release using the included Ruby manager:

```zsh
ruby CodexCage/scripts/manage_codex.rb install
```

The script:

- resolves the latest Codex release from OpenAI;
- downloads the ARM64 Linux musl package;
- downloads the published checksum manifest;
- verifies the package SHA-256;
- extracts the complete Codex package into `CodexCage/vendor/codex`.

The resulting vendor directory contains the full Codex package, including the main CLI binary, helper binaries, package metadata, and bundled resources.

Then build the Docker image:

```zsh
docker build -f CodexCage/Dockerfile -t codex-cage CodexCage
```

### Running CodexCage

Use the provided run script:

```zsh
CodexCage/scripts/run.sh
```

The script starts Codex directly inside a disposable container with:

- `CodexCage/workspace` mounted read/write at `/workspace`;
- `/workspace` as the working directory;
- `CODEX_HOME` set to `/workspace/.codex`;
- no inbound ports exposed during normal use.

Codex has normal internet access so it can communicate with OpenAI services, but the container only receives access to host directories that are explicitly mounted into it.

The container is disposable and runs with `--rm`. The workspace is bind-mounted from the host, so files inside the workspace persist after the container exits.

### Codex login

Codex normally reuses authentication state stored under `CodexCage/workspace/.codex`, so repeated login should not normally be necessary.

When a new browser login is required, run:

```zsh
CodexCage/scripts/run.sh --login
```

Login mode temporarily exposes the Codex OAuth callback through the host loopback interface so the browser can return authentication to Codex running inside the container.

The callback is bound only to `127.0.0.1` on the host and is available only while the login container is running. Normal CodexCage runs do not expose this port.

Complete the normal ChatGPT browser login using the URL provided by Codex. After authentication succeeds, Codex stores its authentication state under `CodexCage/workspace/.codex`.

Future normal runs can then use:

```zsh
CodexCage/scripts/run.sh
```

### Updating Codex

To update Codex, use the same Ruby manager:

```zsh
ruby CodexCage/scripts/manage_codex.rb update
```

The script compares the installed package version against the latest release.

If an update is available, it:

- downloads the new package;
- downloads the published checksum manifest;
- verifies the package SHA-256;
- extracts the new package;
- replaces the existing `CodexCage/vendor/codex` package.

After updating Codex, rebuild the Docker image:

```zsh
docker build -f CodexCage/Dockerfile -t codex-cage CodexCage
```

The Dockerfile copies the complete Codex package into the image:

```dockerfile
COPY vendor/codex /usr/local/codex

ENV PATH="/usr/local/codex/bin:${PATH}"
```

The next CodexCage container will then use the updated version.

You can verify the version baked into the image with:

```zsh
docker run --rm codex-cage codex --version
```

### Codex package layout

Codex is vendored as a complete package instead of a single standalone binary.

The vendor directory looks roughly like:

```text
CodexCage/vendor/codex/
├── bin/
│   ├── codex
│   └── codex-code-mode-host
├── codex-package.json
├── codex-path/
└── codex-resources/
```

Newer versions of Codex use the packaged layout so the CLI can access the helper binaries and resources it expects at runtime.

### Workspace

Only files placed inside the `workspace` are intentionally exposed to the container.

The cage is intentionally simple. Keep the mounted filesystem surface small and only give Codex the code it actually needs.
