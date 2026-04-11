# hosts/shared/

Cross-host identity constants. Files here are plain attrsets imported by both system and Home Manager configs.

## Ownership Boundary

- This directory is a data plane, not a module plane.
- Values here are imported from `hosts/*/configuration.nix` and `hosts/*/home.nix`.
- Keep keys stable: downstream configs assume existing attribute names.

## Where To Look

| Task | File |
|------|------|
| Update signing fingerprints | `gpg-signing-keys.nix` |
| Update SSH auth keygrips | `gpg-ssh-keygrips.nix` |
| Update SSH public keys | `ssh-public-keys.nix` |

## Conventions

- Return plain attrsets only (example: `{ pc-hylia = "..."; }`).
- Keep hostnames in kebab-case and aligned with `hosts/{host}` directory names.
- No side effects, no `imports`, no `config`/`lib` module arguments.

## Anti-Patterns

- **NEVER** convert these files into NixOS/Home Manager modules.
- **NEVER** hardcode the same fingerprint/key in multiple host files; centralize it here.
- **NEVER** rename host keys here without updating all consumers.
