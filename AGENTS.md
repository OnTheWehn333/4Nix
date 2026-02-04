# AGENTS.md

**Generated:** 2026-02-04 | **Commit:** e4a3408 | **Branch:** master

## Overview

NixOS + nix-darwin flake with Home Manager. Manages two hosts: `server-tenoko` (NixOS/x86_64-linux) and `pc-hylia` (Darwin/aarch64-darwin).

## Structure

```
4Nix/
├── flake.nix              # Entry: defines nixosConfigurations + darwinConfigurations
├── hosts/
│   ├── pc-hylia/          # macOS: configuration.nix + home.nix
│   └── server-tenoko/     # NixOS: configuration.nix + home.nix + hardware-configuration.nix
├── home-modules/          # Reusable Home Manager modules (one tool per file)
│   ├── bundles/           # Grouped imports (dev-tools.nix)
│   └── scripts/           # Shell scripts sourced by modules
├── modules/               # NixOS service modules (tak-server.nix)
└── overlays/              # Package overlays (unstable + modifications)
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add new host | `flake.nix` + `hosts/{hostname}/` | Copy existing host structure |
| Add user tool | `home-modules/{tool}.nix` | Import in host's `home.nix` |
| Bundle related tools | `home-modules/bundles/` | Group imports together |
| Add system service | `modules/` | NixOS-only, import in flake.nix |
| Override packages | `overlays/default.nix` | Two overlays: `unstable-packages`, `modifications` |
| Platform-specific packages | Host's `home.nix` | Use `lib.optionals pkgs.stdenv.isDarwin [...]` |

## Conventions

### Module Signature
```nix
{ config, lib, pkgs, ... }: { ... }
```
- Always destructure `config`, `lib`, `pkgs` even if unused (consistency)
- Use `let ... in { ... }` for local bindings

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
- **AVOID** `as any`-style suppressions - all Nix expressions must type-check
- **DO NOT** add platform-specific packages without `lib.optionals` guard

## Unique Patterns

### Dual nixpkgs Input
```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";        # Linux
nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";  # macOS
```
Each platform uses matched Home Manager input (`home-manager` vs `home-manager-darwin`).

### Overlays Architecture
```nix
# overlays/default.nix exports two overlays:
unstable-packages  # Exposes pkgs.unstable.*
modifications      # Package overrides (e.g., opencode = final.unstable.opencode)
```
Applied via `overlaysList` in flake.nix.

### Home Manager Activation Scripts
Several modules use `home.activation.*` for post-install setup:
- `neovim.nix`: Clone/update nvim config from GitHub
- `rust.nix`: Initialize rustup toolchain if missing

### Custom Package Build
`tunnel9.nix` builds Go package from source using `pkgs.buildGoModule`.

## Commands

```bash
# Check flake (ALWAYS before commit)
nix --extra-experimental-features "nix-command flakes" flake check

# Build NixOS (server-tenoko)
sudo nixos-rebuild switch --flake .#server-tenoko

# Build macOS (pc-hylia)
darwin-rebuild switch --flake .#pc-hylia

# Update flake inputs
nix flake update

# Show flake outputs
nix flake show
```

## Host Quick Reference

| Host | Platform | System | Key Services |
|------|----------|--------|--------------|
| `pc-hylia` | macOS | aarch64-darwin | ghostty, nushell, zsh, tunnel9, atac |
| `server-tenoko` | NixOS | x86_64-linux | tak-server (Docker), SSH |

## Module Pattern Reference

### Simple Package Module
```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [ toolname ];
}
```

### Program Configuration Module
```nix
{ config, lib, pkgs, ... }: {
  programs.toolname = {
    enable = true;
    # options...
  };
}
```

### Module with Activation Script
```nix
{ config, lib, pkgs, ... }: let
  # local bindings
in {
  home.packages = [ ... ];
  home.activation.scriptName = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # shell commands
  '';
}
```

### NixOS Service Module
```nix
{ config, lib, pkgs, ... }: let
  cfg = config.services.servicename;
in {
  options.services.servicename = {
    enable = lib.mkEnableOption "description";
    # more options with lib.mkOption
  };
  config = lib.mkIf cfg.enable {
    # implementation
  };
}
```

## Notes

- `1password.nix` is fully commented out (WIP)
- `wezterm.nix` has `enable = false` (disabled in favor of ghostty)
- Server uses bash→nushell auto-exec (`programs.bash.interactiveShellInit`)
- neovim config lives externally at `github:OnTheWehn333/nvim-config`
