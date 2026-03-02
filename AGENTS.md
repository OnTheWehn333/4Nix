# AGENTS.md

NixOS + nix-darwin + WSL flake with Home Manager. Three hosts, secrets via sops-nix, GPG subkey sync via custom Go tool (`keysync`).

## Commands

```bash
# Validate flake (ALWAYS before commit — required gate)
nix --extra-experimental-features "nix-command flakes" flake check

# Build & switch per host
sudo nixos-rebuild switch --flake .#server-tenoko    # NixOS
sudo nixos-rebuild switch --flake .#pc-akkala         # WSL
darwin-rebuild switch --flake .#pc-hylia              # macOS

# Bootstrap (first-time machine — keysync only, minimal HM)
sudo nixos-rebuild switch --flake .#server-tenoko-bootstrap
sudo nixos-rebuild switch --flake .#pc-akkala-bootstrap
darwin-rebuild switch --flake .#pc-hylia-bootstrap

# Flake management
nix flake update          # Update all inputs
nix flake show            # Show outputs
nix flake lock --update-input nixpkgs   # Update single input

# Secrets
sops secrets/pc-hylia/secrets.yaml      # Edit encrypted secrets (requires GPG key)

# Keysync (Go tool — tools/keysync/)
go build ./cmd/keysync/        # Build locally (from tools/keysync/)
go vet ./...                   # Lint
go test ./...                  # Run tests (currently none — doCheck=false in nix)
```

## Structure

```
4Nix/
├── flake.nix              # Entry: 6 configs (3 hosts × normal+bootstrap)
├── hosts/
│   ├── pc-hylia/          # macOS (aarch64-darwin): configuration.nix + home.nix + home-bootstrap.nix
│   ├── pc-akkala/         # WSL (x86_64-linux): configuration.nix + home.nix + home-bootstrap.nix
│   ├── server-tenoko/     # NixOS (x86_64-linux): + hardware-configuration.nix (DO NOT EDIT)
│   └── shared/            # Plain attrsets: GPG keys, SSH keys, keygrips
├── home-modules/          # Reusable HM modules (one tool per file, ~30 modules)
│   ├── bundles/           # Grouped imports (dev-tools.nix)
│   └── scripts/           # Shell scripts sourced by modules
├── modules/               # NixOS service modules (tak-server.nix)
├── overlays/              # Package overlays (unstable-packages + modifications)
├── secrets/               # sops-encrypted per-host + shared secrets
└── tools/keysync/         # Go CLI: GPG subkey backup/restore via 1Password
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add user tool | `home-modules/{tool}.nix` | Import in host's `home.nix` |
| Add system service | `modules/` | NixOS-only, import in `flake.nix` |
| Override/pin package | `overlays/default.nix` | Two overlays: `unstable-packages`, `modifications` |
| Add host-specific pkg | `hosts/{host}/home.nix` | Use `lib.optionals` for platform guards |
| Add/edit secrets | `secrets/{host}/` + `.sops.yaml` | Keyed per host PGP fingerprint |
| Share data across hosts | `hosts/shared/*.nix` | Plain attrsets, NOT module functions |
| Add new host | Copy existing host dir + add entries in `flake.nix` | Need both normal + bootstrap configs |

## Code Style — Nix

### Module Signature
```nix
{ config, lib, pkgs, ... }: { ... }
```
- Always destructure `config`, `lib`, `pkgs` even if unused
- Use `let ... in { ... }` for local bindings
- Access flake inputs via `inputs` arg (passed through `extraSpecialArgs`)

### Imports & Paths
- `imports = [ ... ];` at top of module body
- Relative paths: `../../home-modules/module.nix`
- Shared data: `import ../shared/file.nix` (returns plain attrset)

### Packages
- `with pkgs;` in package lists: `home.packages = with pkgs; [ tool1 tool2 ];`
- Platform guards: `lib.optionals (!pkgs.stdenv.isDarwin) [ gcc gnumake ]`
- Do NOT use `with pkgs;` for single-package `let` bindings

### Formatting
- 2-space indent, never tabs
- `nixpkgs-fmt` style (no trailing commas in attrsets)
- Filenames: kebab-case (`dev-tools.nix`, `oh-my-posh.nix`)
- Hostnames: kebab-case (`pc-hylia`, `server-tenoko`, `pc-akkala`)

### Module Patterns (home-modules/)

**Simple package** — `home.packages = with pkgs; [ tool ];`
**Program config** — `programs.X.enable = true;` with settings
**Activation script** — `home.activation.X = lib.hm.dag.entryAfter ["writeBoundary"] ''...'';`
**Custom build** — `let pkg = pkgs.buildGoModule { ... }; in { home.packages = [pkg]; }`
**Custom option** — `options.custom.X = lib.mkEnableOption ...;` + `config = { ... };`
**Script wrapper** — `pkgs.writeShellApplication` reading from `scripts/`

### Sops-nix Secrets Pattern
```nix
# In host home.nix:
sops.defaultSopsFile = ../../secrets/{host}/secrets.yaml;
sops.gnupg.home = "${config.home.homeDirectory}/.gnupg";

# In module:
sops.secrets."key-name" = { sopsFile = ../secrets/shared/secrets.yaml; };
sops.templates."config-name" = {
  content = builtins.toJSON (lib.recursiveUpdate baseSettings secretSettings);
  path = "${config.xdg.configHome}/app/config.json";
};
```

## Code Style — Go (tools/keysync/)

- Go 1.24, cobra CLI, yaml.v3 for config
- `internal/` packages — not importable externally
- Config file at repo root (`keysync.yaml`), not inside tool directory
- After changing Go deps: update `vendorHash` in `home-modules/keysync.nix`

## Architecture Notes

### Dual Inputs Per Platform
Each platform (Linux/Darwin) has its own matched set: nixpkgs + home-manager + sops-nix. HM integrated as NixOS/darwin module (not standalone).

### Six Flake Configurations
3 hosts × 2 variants (normal + bootstrap). Bootstrap uses `lib.mkForce` to override HM user with minimal `home-bootstrap.nix` (keysync + home-manager only).

### Overlays
```nix
unstable-packages  # Exposes pkgs.unstable.* from nixos-unstable
modifications      # Package pins/overrides (opencode, azure-cli, tmuxPlugins.tome)
```
Applied via `overlaysList`. Darwin also gets `nix-darwin.overlays.default`.

## Host Quick Reference

| Host | Platform | System | Shell | Extra Modules | Services |
|------|----------|--------|-------|---------------|----------|
| `pc-hylia` | macOS | aarch64-darwin | zsh | ghostty, tunnel9, atac, scrcpy, android-tools, agenix, azure, k8s, terraform | SSH |
| `pc-akkala` | WSL | x86_64-linux | zsh | tunnel9, atac, scrcpy, android-tools, agenix, azure, k8s, terraform | SSH |
| `server-tenoko` | NixOS | x86_64-linux | bash→nushell | (minimal) | tak-server (Docker), SSH |

## Anti-Patterns

- **NEVER** modify `hardware-configuration.nix` — auto-generated by NixOS
- **NEVER** commit without `nix flake check` passing
- **NEVER** add platform-specific packages without `lib.optionals` guard
- **NEVER** hardcode GPG fingerprints — use `hosts/shared/*.nix`
- **NEVER** put secrets in plain text — use sops-nix (`secrets/` directory)
- **NEVER** add sops secrets without updating `.sops.yaml` path regex + PGP key
- **NEVER** import host-specific logic in home-modules — must work on all platforms
- **NEVER** hardcode paths — use `config.home.homeDirectory` or `config.xdg.configHome`

## Notes

- `wezterm.nix` has `enable = false` (disabled in favor of ghostty)
- Neovim config is external: `github:OnTheWehn333/nvim-config`
- `keysync.yaml` at repo root defines GPG key hierarchy and per-host subkey assignments
- All hosts share the same GPG signing key but have unique encrypt/auth subkeys
- `keysync.nix` imports `gpg.nix` — only home-module with an internal dependency
- `oh-my-posh.nix` dynamically patches theme JSON with Tokyo Night colors per host
