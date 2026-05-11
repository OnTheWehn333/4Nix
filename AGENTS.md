# 4Nix Agent Map

This repo is Noah's personal Nix configuration: NixOS + nix-darwin + WSL, Home Manager, sops-nix secrets, overlays, and custom tooling.

The durable AI knowledge layer for this repo lives in the Nix workflow:

```text
~/ObsidianVaults/4V2/Workflows/Nix/4Nix/4Nix.md
```

Use this file as the repo-local map and safety contract. Use the workflow note for richer architecture/convention memory when available. The live repo always wins when it disagrees with workflow notes.

## Read order

1. Read this file first.
2. If available and the task needs architecture context, read `~/ObsidianVaults/4V2/Workflows/Nix/4Nix/CONTEXT.md` and `~/ObsidianVaults/4V2/Workflows/Nix/4Nix/4Nix.md`.
3. Route to the right repo area using the table below.
4. Read the nearest nested `AGENTS.md` before editing inside that area.
5. Read targeted files and nearby examples before proposing changes.

## Map → Rooms → Tools

### Map

- `AGENTS.md` — repo-local map, routing, and safety rules.
- `CLAUDE.md` — Claude-specific entry point; should defer to `AGENTS.md`.
- Workflow note — durable AI knowledge for architecture and recurring conventions.

### Rooms

| Room | Purpose | Local context |
| --- | --- | --- |
| `hosts/` | Host identity, platform divergence, imports, bootstrap flow. | `hosts/AGENTS.md` |
| `hosts/shared/` | Plain shared host data: GPG fingerprints/keygrips and SSH public keys. | `hosts/shared/AGENTS.md` |
| `home-modules/` | Reusable Home Manager modules, usually one tool per file. | `home-modules/AGENTS.md` |
| `home-modules/scripts/` | Shell sources wrapped by Home Manager modules. | `home-modules/scripts/AGENTS.md` |
| `modules/` | NixOS-only system modules/services. | `modules/AGENTS.md` |
| `overlays/` | nixpkgs overlays, unstable package exposure, package/plugin modifications. | `overlays/AGENTS.md` |
| `secrets/` | sops-encrypted secret payloads only. | `secrets/AGENTS.md` |
| `tools/keysync/` | Go CLI for GPG subkey backup/restore via 1Password. | `tools/keysync/AGENTS.md` |

### Tools

- `flake.nix` — repo entry point for NixOS, nix-darwin, WSL, Home Manager, overlays, and bootstrap outputs.
- `.playbook.sh` — Tome/ad hoc command playbook. Noah runs risky/frequent commands from here manually.
- `keysync.yaml` — root-level keysync config. Do not move it under `tools/keysync/`.

## Routing

| Task | Go to | Read | Output |
| --- | --- | --- | --- |
| Add a user tool or Home Manager config | `home-modules/` | `home-modules/AGENTS.md`, nearby modules, target host `home.nix` | Module change + host import if needed |
| Bundle related user tools | `home-modules/bundles/` | `home-modules/AGENTS.md`, existing bundle | Bundle update |
| Add host-specific package/config | `hosts/{host}/` | `hosts/AGENTS.md`, target host files | Host-scoped change |
| Add/change NixOS-only service | `modules/` | `modules/AGENTS.md`, importing host/flake context | System module + import/wiring |
| Change overlay/package override | `overlays/` | `overlays/AGENTS.md`, `overlays/default.nix` | Overlay change |
| Add/edit secret wiring | `secrets/` + consumer module/host | `secrets/AGENTS.md`, `.sops.yaml`, consumer file | Encrypted secret path/routing + sops wiring |
| Change shared keys/constants | `hosts/shared/` | `hosts/shared/AGENTS.md` | Plain attrset update |
| Change keysync behavior | `tools/keysync/` | `tools/keysync/AGENTS.md`, nested internal context when needed | Go/Nix bridge change |
| Add reusable command handoff | repo root | `.playbook.sh`, this file | Tome playbook entry |

## Core conventions

- Nix module signature: `{ config, lib, pkgs, ... }:` even when args appear unused.
- Keep `imports = [ ... ];` near the top of module bodies.
- Use `home.packages = with pkgs; [ ... ];` for package lists.
- Do not use `with pkgs;` for single-package `let` bindings.
- Keep host-specific logic in `hosts/`; `home-modules/` should remain host-agnostic.
- Guard platform-specific packages with `lib.optionals`.
- Prefer `config.home.homeDirectory` and `config.xdg.configHome` over hardcoded absolute paths.
- Keep shared host constants in `hosts/shared/*.nix` as plain attrsets, not modules.

## Command policy

Safe checks agents may run after stating intent:

```bash
nix flake show --no-write-lock-file
nix --extra-experimental-features "nix-command flakes" flake check --no-write-lock-file
```

Manual-only by default; put these in `.playbook.sh` for Noah to run:

- `nh` switch/build/test/boot commands when used as system/profile operations.
- `nixos-rebuild`, `darwin-rebuild`, `home-manager switch`, or any activation/switch command.
- Secrets, key restore, 1Password, or sops commands that may expose or mutate sensitive material.
- Global/system installs outside Nix.

Noah handles git commits and pushes manually. Agents should provide a change summary instead of committing.

## Playbook policy

- `.playbook.sh` is a Tome playbook, not a conventional script entrypoint.
- Keep commands line-oriented and easy to send from Tome.
- Use comments to group commands.
- Use Tome variables like `$<host>=pc-hylia` and `$<host>` for values Noah may change before running.
- Prefer `nh` commands for build/test/switch handoffs where appropriate.
- Keep secrets/key commands as explicit manual handoffs; never include secret values.

## Hard rules

- Never edit `hosts/server-tenoko/hardware-configuration.nix`.
- Never commit plaintext secrets or decrypted artifacts.
- Never add secret files/rules without updating `.sops.yaml` key routing.
- Never hardcode GPG fingerprints/keygrips/public keys in multiple places; use `hosts/shared/*.nix`.
- Never move `keysync.yaml` under `tools/keysync/`.
- Never run switch/rebuild/activation or secrets commands directly as an agent.
- Do not apply work/client repo assumptions here.

## Validation

Before handing off substantial changes, run or suggest:

```bash
nix --extra-experimental-features "nix-command flakes" flake check --no-write-lock-file
```

For Go changes in `tools/keysync/`, also consider from `tools/keysync/`:

```bash
go build ./cmd/keysync/
go vet ./...
go test ./...
```
