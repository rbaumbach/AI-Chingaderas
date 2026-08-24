# CodexCage Workspace

This directory is the only host directory mounted into the CodexCage container.

Projects placed here are made available to Codex for reading and writing.

## Additional Settings

If you would like to persist the permission settings the following can be added to `.codex/config.toml`:

```
approval_policy = "on-request"
```