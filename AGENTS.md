# PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-10 America/Chicago
**Commit:** 9638658
**Branch:** master

NixOS + nix-darwin + WSL flake with Home Manager. Three hosts, sops-nix secrets, and a custom Go `keysync` tool for GPG subkey sync.

## Structure

```
4Nix/
├── flake.nix              # Entry: 6 outputs (3 hosts x normal/bootstrap)
├── hosts/                 # Host identity + shared key metadata
├── home-modules/          # Reusable HM modules (one tool per file)
├── modules/               # NixOS-only services
├── overlays/              # unstable-packages + modifications overlays
├── secrets/               # sops-encrypted host/shared secrets
└── tools/keysync/         # Go CLI for GPG subkey backup/restore
```

## Hierarchy

- `hosts/AGENTS.md` for host-level imports, bootstrap flow, and platform divergence.
- `hosts/shared/AGENTS.md` for plain-attrset data rules (no module logic).
- `home-modules/AGENTS.md` for HM module patterns and anti-patterns.
- `tools/keysync/AGENTS.md` for Go CLI boundaries and Nix bridge constraints.
- `tools/keysync/internal/AGENTS.md` for internal package ownership rules.
- `secrets/AGENTS.md` for encrypted secret lifecycle and `.sops.yaml` coupling.

## Where To Look

| Task | Location | Notes |
|------|----------|-------|
| Add user tool | `home-modules/{tool}.nix` | Import in host `home.nix` |
| Add system service | `modules/` | Import in `flake.nix` (NixOS only) |
| Add host package | `hosts/{host}/home.nix` | Guard platform-only packages with `lib.optionals` |
| Add/edit secret | `secrets/{host}/secrets.yaml` | Update `.sops.yaml` rules and host key mapping |
| Share host constants | `hosts/shared/*.nix` | Plain attrsets only |
| Change keysync behavior | `tools/keysync/internal/*` | Keep adapters separated from orchestration |

## Commands

```bash
# Required validation gate before commit
nix --extra-experimental-features "nix-command flakes" flake check

# Build & switch per host
sudo nixos-rebuild switch --flake .#server-tenoko
sudo nixos-rebuild switch --flake .#pc-akkala
darwin-rebuild switch --flake .#pc-hylia

# Bootstrap (first-time key restore path)
sudo nixos-rebuild switch --flake .#server-tenoko-bootstrap
sudo nixos-rebuild switch --flake .#pc-akkala-bootstrap
darwin-rebuild switch --flake .#pc-hylia-bootstrap

# Flake management
nix flake update
nix flake show
nix flake lock --update-input nixpkgs

# Secrets
sops secrets/pc-hylia/secrets.yaml

# Keysync (run inside tools/keysync)
go build ./cmd/keysync/
go vet ./...
go test ./...
```

## Conventions

- Nix module signature: `{ config, lib, pkgs, ... }:` even when args appear unused.
- Keep `imports = [ ... ];` at top of module body.
- Use `with pkgs;` in package lists, not single-package `let` bindings.
- Keep host logic in `hosts/`; `home-modules/` must remain host-agnostic.
- Keep secret references path-based (`config.home.homeDirectory` / `config.xdg.configHome`), never hardcoded absolute paths.
- `keysync.yaml` stays at repository root; do not move it under `tools/keysync/`.

## Anti-Patterns

- **NEVER** edit `hosts/server-tenoko/hardware-configuration.nix`.
- **NEVER** commit without `nix flake check` passing.
- **NEVER** hardcode GPG fingerprints; use `hosts/shared/*.nix`.
- **NEVER** add platform-specific packages without `lib.optionals` guards.
- **NEVER** commit plaintext secrets; use sops-encrypted files only.
- **NEVER** add secret files/rules without updating `.sops.yaml` key routing.

## Notes

- `home-modules/opencode-profiles.nix` is the largest complexity hotspot; treat changes as cross-cutting.
- `keysync.nix` imports `gpg.nix`; this is the only home-module internal dependency.
- No CI workflow is defined in repo; validation is command-driven.
