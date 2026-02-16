# tools/keysync/

Go CLI for GPG subkey backup/restore via 1Password. Built by `home-modules/keysync.nix` using `pkgs.buildGoModule`.

## Structure

```
keysync/
├── cmd/keysync/main.go          # Entry: cobra root command
├── internal/
│   ├── config/config.go         # Parse keysync.yaml (repo root)
│   ├── engine/
│   │   ├── backup.go            # Export subkeys → 1Password vault
│   │   ├── restore.go           # 1Password vault → import subkeys
│   │   └── sync.go              # Orchestrates backup/restore per host
│   ├── gpg/
│   │   ├── export.go            # gpg --export-secret-subkeys wrapper
│   │   └── import.go            # gpg --import wrapper
│   └── op/client.go             # 1Password CLI (op) wrapper
├── go.mod                       # module github.com/OnTheWehn333/keysync
└── go.sum
```

## Where to Look

| Task | File |
|------|------|
| Add CLI subcommand | `cmd/keysync/main.go` (cobra) |
| Change key export logic | `internal/gpg/export.go` |
| Change 1Password integration | `internal/op/client.go` |
| Change sync orchestration | `internal/engine/sync.go` |
| Change config format | `internal/config/config.go` + `keysync.yaml` (repo root) |

## Conventions

- Go 1.24, cobra for CLI, yaml.v3 for config
- `internal/` packages — not importable externally
- Config file lives at repo root (`keysync.yaml`), NOT inside this directory
- No tests (`doCheck = false` in nix build) — CLI tool tested manually

## Notes

- Nix build uses local source path (`src = ../tools/keysync`) with pinned `vendorHash`
- After modifying Go dependencies: update `vendorHash` in `home-modules/keysync.nix`
- `keysync.yaml` defines GPG key hierarchy: identity key + per-host encrypt/auth subkeys
- Each host gets: shared signing subkey + unique encrypt + unique auth subkeys
