# AGENTS.md

## Build Commands
- **Check flake**: `nix --extra-experimental-features "nix-command flakes" flake check`
- **Build NixOS (server-tenoko)**: `sudo nixos-rebuild switch --flake .#server-tenoko`
- **Build macOS (pc-hylia)**: `darwin-rebuild switch --flake .#pc-hylia`
- **Update inputs**: `nix flake update`
- **Show outputs**: `nix flake show`

## Code Style
- **Module structure**: Always use `{ config, lib, pkgs, ... }: { ... }` for modules
- **Imports**: Place `imports = [ ... ];` at the top of module definitions
- **Let-in bindings**: Use `let ... in { ... }` for complex expressions and variable assignments
- **Indentation**: 2 spaces (never tabs)
- **Package lists**: Use `with pkgs;` for cleaner package references in lists
- **Conditionals**: Use `lib.optionals` for conditional list items (e.g., platform-specific packages)
- **Comments**: Use `#` for inline comments, document complex logic
- **Overlays**: Define in `overlays/default.nix`, import via `overlaysList` in flake.nix
- **Home Manager modules**: Create reusable modules in `home-modules/`, import in host-specific `home.nix`
- **Bundles**: Group related modules in `home-modules/bundles/` for common configurations
- **String interpolation**: Use `"${expression}"` for Nix expressions in strings
- **Naming**: Use kebab-case for file names (e.g., `dev-tools.nix`), hostnames (e.g., `pc-hylia`)
- **Error handling**: Validate with `nix flake check` before committing changes
