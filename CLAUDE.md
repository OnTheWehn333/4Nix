# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a NixOS + nix-darwin flake configuration with Home Manager for managing system configurations across multiple hosts. The flake supports both Linux (NixOS) and macOS (nix-darwin) hosts.

## Architecture

### Host Configuration Structure
- **flake.nix**: Main flake file defining outputs for each host
- **hosts/**: Host-specific configurations
  - `pc-hylia/`: macOS host (aarch64-darwin) using nix-darwin
  - `server-tenoko/`: NixOS host (x86_64-linux)
- **home-modules/**: Reusable Home Manager modules
  - `bundles/`: Collections of related modules (e.g., dev-tools.nix)
  - Individual module files for specific tools/programs

### Key Hosts
- **pc-hylia**: macOS host using nix-darwin.lib.darwinSystem
- **server-tenoko**: NixOS host using nixpkgs.lib.nixosSystem

## Build Commands

Since this is a Nix flake configuration, build commands differ per host:

### For NixOS (server-tenoko)
```bash
sudo nixos-rebuild switch --flake .#server-tenoko
```

### For macOS (pc-hylia)
```bash
darwin-rebuild switch --flake .#pc-hylia
```

### Development Commands
```bash
# Check flake configuration
nix flake check

# Show flake outputs
nix flake show

# Update flake inputs
nix flake update
```

## Module System

Home Manager modules are organized in `home-modules/` and imported per-host in the respective `home.nix` files. Common patterns:

- Modules are imported using relative paths: `../../home-modules/module.nix`
- Bundle modules collect related functionality: `bundles/dev-tools.nix`
- Host-specific packages are defined in each host's `home.nix`

## Configuration Flow

1. **flake.nix** defines the main structure and inputs
2. **hosts/[hostname]/configuration.nix** handles system-level config
3. **hosts/[hostname]/home.nix** imports Home Manager modules
4. **home-modules/** contain reusable user environment configurations

## Helpful Commands

- When needing to check the configuration run this command: nix --extra-experimental-features "nix-command flakes" flake check