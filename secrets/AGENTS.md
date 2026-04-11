# secrets/

Encrypted secret payloads for hosts and shared consumers. This directory is data-only; decryption/enforcement lives in host `home.nix` + sops-nix modules.

## Structure

```
secrets/
├── pc-hylia/secrets.yaml
├── pc-akkala/secrets.yaml
├── server-tenoko/secrets.yaml
└── shared/secrets.yaml
```

## Where To Look

| Task | File | Notes |
|------|------|-------|
| Add host secret | `secrets/{host}/secrets.yaml` | Keep host-only values local |
| Add shared secret | `secrets/shared/secrets.yaml` | For values consumed by multiple hosts/modules |
| Route encryption keys | `.sops.yaml` (repo root) | Must match new/changed path regex |
| Wire secret to config | `hosts/{host}/home.nix` or module file | Use `sops.secrets` / `sops.templates` |

## Conventions

- Only encrypted `sops` payloads are allowed in this directory.
- Keep host files scoped to that host's lifecycle and key ownership.
- Shared secrets should be minimal and intentionally multi-host.
- Path changes require matching `.sops.yaml` updates in the same change.

## Anti-Patterns

- **NEVER** commit plaintext values or decrypted artifacts.
- **NEVER** add a new secret path without updating `.sops.yaml` creation rules.
- **NEVER** move or rename secret files without updating host/module references.
- **NEVER** hardcode secrets directly in Nix modules when `sops.secrets` can supply them.
