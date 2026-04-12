# tools/keysync/internal/

Internal Go packages for `keysync`. Keep orchestration in `engine`, adapters in `gpg`/`op`, schema in `config`.

## Package Roles

| Package | Role | Must Not Do |
|---------|------|-------------|
| `config` | Parse and validate `keysync.yaml` | Invoke external CLIs |
| `engine` | Orchestrate sync/backup/restore flows | Re-implement CLI parsing |
| `gpg` | Wrap GPG import/export/list operations | Call 1Password APIs/CLI |
| `op` | Wrap 1Password item read/write/list operations | Parse top-level keysync schema |

## Conventions

- Keep package boundaries strict: adapters stay independent; `engine` composes them.
- Preserve non-interactive execution flags (`--batch`, `--no-tty`, `OP_NO_PROMPT=1`).
- Treat key material as sensitive byte streams; avoid disk writes for transient secrets.
- Keep config assumptions aligned with repo-root `keysync.yaml`.

## Contracts

- 1Password item titles come from `key.Title + "/" + subkeyName`; preserve that lookup shape when touching `config.ResolveRef` or `op` reads.
- 1Password field names are stable API: `fingerprint`, `algorithm`, `capabilities`, `uid`, `created`, `expires`, `public_key`, `secret_key`, `sha256_public`, `sha256_secret`, `synced_at`.
- Secret subkey exports must keep the `!` suffix convention before `gpg --export-secret-subkeys`; dropping it changes export scope.

## Anti-Patterns

- **NEVER** couple `gpg` directly to `op`; coordinate through `engine`.
- **NEVER** move `keysync.yaml` lookup into this directory.
- **NEVER** add cross-package imports that bypass `engine` ownership.
- **NEVER** change data fields persisted to 1Password without updating all readers/writers.
