# 4Nix Claude Entry

Read `AGENTS.md` first. It is the repo-local map, routing table, and safety contract for this Nix configuration.

If the broader Nix workflow is available, use it as the durable AI knowledge layer:

```text
~/ObsidianVaults/4V2/Workflows/Nix/CLAUDE.md
~/ObsidianVaults/4V2/Workflows/Nix/4Nix/CONTEXT.md
~/ObsidianVaults/4V2/Workflows/Nix/4Nix/4Nix.md
```

The live repo is the implementation source of truth. Workflow notes provide orientation, but current repo files and nearby patterns win when they disagree.

## Claude-specific operating rules

- Route by `AGENTS.md` before editing.
- Read the nearest nested `AGENTS.md` for the target folder.
- Inspect targeted files and nearby examples before proposing changes.
- Prefer a short plan before broad edits.
- Keep changes small and reviewable.
- Run safe checks only after stating intent.
- Do not run switch/rebuild/activation, secrets, key restore, global install, commit, or push commands.
- For risky/frequent commands, add or update `.playbook.sh` as a Tome handoff for Noah to run manually.

## Safe checks

```bash
nix flake show --no-write-lock-file
nix --extra-experimental-features "nix-command flakes" flake check --no-write-lock-file
```
