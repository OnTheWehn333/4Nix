# AGENTS.md

**Generated:** 2026-02-15 | **Commit:** d70dfda | **Branch:** master

## Overview

NixOS + nix-darwin flake with Home Manager. Two hosts: `server-tenoko` (NixOS/x86_64-linux) and `pc-hylia` (Darwin/aarch64-darwin). Secrets via sops-nix. GPG subkey sync via custom Go tool (`keysync`).

## Structure

```
4Nix/
├── flake.nix                # Entry: nixosConfigurations + darwinConfigurations (4 total)
├── hosts/
│   ├── pc-hylia/            # macOS: configuration.nix + home.nix + home-bootstrap.nix
│   ├── server-tenoko/       # NixOS: configuration.nix + home.nix + home-bootstrap.nix
│   └── shared/              # Cross-host data: GPG keys, SSH keys, keygrips
├── home-modules/            # Reusable HM modules (one tool per file, 24 modules)
│   ├── bundles/             # Grouped imports (dev-tools.nix)
│   └── scripts/             # Shell scripts sourced by modules
├── modules/                 # NixOS service modules (tak-server.nix, traefik-cf-tunnel.nix)
├── overlays/                # Package overlays (unstable + modifications)
├── secrets/                 # sops-encrypted per-host + shared secrets (not in git)
│   ├── pc-hylia/
│   ├── server-tenoko/
│   └── shared/
└── tools/keysync/           # Go CLI: GPG subkey backup/restore via 1Password
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add new host | `flake.nix` + `hosts/{hostname}/` | Copy existing host, add both normal + bootstrap configs |
| Add user tool | `home-modules/{tool}.nix` | Import in host's `home.nix` |
| Bundle related tools | `home-modules/bundles/` | Group imports together |
| Add system service | `modules/` | NixOS-only, import in `flake.nix` nixosConfigurations |
| Override packages | `overlays/default.nix` | Two overlays: `unstable-packages`, `modifications` |
| Platform-specific packages | Host's `home.nix` | Use `lib.optionals pkgs.stdenv.isDarwin [...]` |
| Add/edit secrets | `secrets/{hostname}/` + `.sops.yaml` | Encrypt with `sops`, keyed per host PGP fingerprint |
| Share data across hosts | `hosts/shared/*.nix` | Plain attrsets imported by both hosts |
| Bootstrap new machine | Build `{host}-bootstrap` config | Minimal HM with keysync only, for key restore |

## Conventions

### Module Signature
```nix
{ config, lib, pkgs, ... }: { ... }
```
- Always destructure `config`, `lib`, `pkgs` even if unused (consistency)
- Use `let ... in { ... }` for local bindings
- Access flake inputs via `inputs` arg (passed through `extraSpecialArgs`)

### Imports
- Place `imports = [ ... ];` at top of module body
- Use relative paths: `../../home-modules/module.nix`

### Packages
- `with pkgs;` for package lists: `home.packages = with pkgs; [ tool1 tool2 ];`
- Platform conditionals: `lib.optionals (!pkgs.stdenv.isDarwin) [ gcc gnumake ]`

### Naming
- Files: kebab-case (`dev-tools.nix`, `oh-my-posh.nix`)
- Hostnames: kebab-case (`pc-hylia`, `server-tenoko`)

### Formatting
- 2-space indent, never tabs
- `nixpkgs-fmt` style (no trailing commas in attrsets)

## Anti-Patterns

- **DO NOT** modify `hardware-configuration.nix` (auto-generated)
- **NEVER** commit without running `nix flake check`
- **DO NOT** add platform-specific packages without `lib.optionals` guard
- **DO NOT** hardcode GPG fingerprints in host configs — use `hosts/shared/*.nix`
- **DO NOT** put secrets in plain text — use sops-nix (`secrets/` directory)

## Unique Patterns

### Dual nixpkgs + Dual sops-nix Inputs
```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";             # Linux
nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";  # macOS
sops-nix.inputs.nixpkgs.follows = "nixpkgs";                   # Linux secrets
sops-nix-darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";     # macOS secrets
```
Each platform uses matched Home Manager + sops-nix input. HM integrated as NixOS/darwin module (not standalone).

### Four Flake Configurations
Normal + bootstrap variant per host. Bootstrap configs use `lib.mkForce` to override HM user with minimal `home-bootstrap.nix` (keysync + home-manager only).

### Overlays Architecture
```nix
# overlays/default.nix exports two overlays:
unstable-packages  # Exposes pkgs.unstable.* from nixos-unstable
modifications      # Package overrides (opencode, tmuxPlugins.tome)
```
Applied via `overlaysList` in flake.nix. Darwin also gets `nix-darwin.overlays.default`.

### Custom Package Builds (buildGoModule)
- `tunnel9.nix`: SSH tunnel TUI, fetched from GitHub
- `keysync.nix`: Local Go source at `../tools/keysync`, GPG subkey sync to 1Password

### Home Manager Activation Scripts
- `neovim.nix`: Clone/update nvim config from `github:OnTheWehn333/nvim-config`
- `rust.nix`: Initialize rustup stable toolchain if missing
- `opencode.nix`: Install Playwright Chromium + inject Context7 API key into config

### Shared Host Data Pattern
`hosts/shared/` contains plain Nix attrsets (not modules) imported via `import ../shared/file.nix`:
- `gpg-signing-keys.nix`: Per-host GPG signing key fingerprints
- `gpg-ssh-keygrips.nix`: Per-host SSH authentication keygrips
- `ssh-public-keys.nix`: Per-host SSH public keys (for cross-host authorized_keys)

### Secret Management (sops-nix)
- `.sops.yaml` maps path regex → PGP fingerprint per host
- Each host imports its sops-nix HM module variant (`sops-nix` vs `sops-nix-darwin`)
- `sops.defaultSopsFile` points to `../../secrets/{host}/secrets.yaml`
- `sops.gnupg.home` uses `${config.home.homeDirectory}/.gnupg`

### opencode.nix Custom Options
Defines `config.custom.opencode.useLatest` option — when enabled, builds from latest GitHub release binary instead of nixpkgs. Includes multi-platform binary download support and oh-my-opencode configuration.

## Commands

```bash
# Check flake (ALWAYS before commit)
nix --extra-experimental-features "nix-command flakes" flake check

# Build NixOS (server-tenoko)
sudo nixos-rebuild switch --flake .#server-tenoko

# Build macOS (pc-hylia)
darwin-rebuild switch --flake .#pc-hylia

# Bootstrap (first-time machine setup — keysync only)
sudo nixos-rebuild switch --flake .#server-tenoko-bootstrap
darwin-rebuild switch --flake .#pc-hylia-bootstrap

# Update flake inputs
nix flake update

# Show flake outputs
nix flake show
```

## Host Quick Reference

| Host | Platform | System | Key Modules | Services |
|------|----------|--------|-------------|----------|
| `pc-hylia` | macOS | aarch64-darwin | ghostty, nushell, zsh, tunnel9, atac, scrcpy, android-tools | SSH |
| `server-tenoko` | NixOS | x86_64-linux | nushell (via bash auto-exec), tmux, opencode | tak-server (Docker), SSH |

## Notes

- `wezterm.nix` has `enable = false` (disabled in favor of ghostty)
- `traefik-cf-tunnel.nix` exists but is empty (WIP)
- Server uses bash→nushell auto-exec (`programs.bash.interactiveShellInit`)
- Neovim config lives externally at `github:OnTheWehn333/nvim-config`
- `keysync.yaml` at repo root defines GPG key hierarchy and per-host subkey assignments
- Both hosts share the same GPG signing key but have unique encrypt/auth subkeys
