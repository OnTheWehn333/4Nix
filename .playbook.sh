# 4Nix Tome Playbook
#
# Open with Tome/tmux or edit directly. Send individual lines/paragraphs manually.
# This is a playbook, not a conventional script entrypoint.
# Agents may add safe handoff commands here, but Noah runs them.

# ─────────────────────────────────────────────────────────────
# Safe inspection / validation
# ─────────────────────────────────────────────────────────────

nix flake show --no-write-lock-file
nix --extra-experimental-features "nix-command flakes" flake check --no-write-lock-file

# ─────────────────────────────────────────────────────────────
# nh build/test handoffs
# ─────────────────────────────────────────────────────────────

# Darwin host
nh darwin switch . -H pc-hylia
nh darwin build . -H pc-hylia
nh darwin test . -H pc-hylia

# WSL / NixOS host
nh os switch . -H pc-akkala
nh os build . -H pc-akkala
nh os test . -H pc-akkala
nh os boot . -H pc-akkala

# NixOS server
nh os switch . -H server-tenoko
nh os build . -H server-tenoko
nh os test . -H server-tenoko
nh os boot . -H server-tenoko

# Clean user generations
nh clean user --keep 5 --keep-since 14d

# If nh is not available in the current shell
nix shell nixpkgs#nh

# ─────────────────────────────────────────────────────────────
# Legacy rebuild fallbacks / bootstrap handoffs
# Prefer nh above when possible. Keep these for bootstrap or recovery.
# ─────────────────────────────────────────────────────────────

# Normal hosts
sudo nixos-rebuild switch --flake .#server-tenoko
sudo nixos-rebuild switch --flake .#pc-akkala
darwin-rebuild switch --flake .#pc-hylia

# Bootstrap profiles
sudo nixos-rebuild switch --flake .#server-tenoko-bootstrap
sudo nixos-rebuild switch --flake .#pc-akkala-bootstrap
darwin-rebuild switch --flake .#pc-hylia-bootstrap

# ─────────────────────────────────────────────────────────────
# Flake management
# ─────────────────────────────────────────────────────────────

nix flake show --no-write-lock-file
nix flake update
nix flake lock --update-input nixpkgs
nix flake lock --update-input nixpkgs-darwin
nix flake lock --update-input home-manager
nix flake lock --update-input home-manager-darwin
nix flake lock --update-input nix-darwin

# ─────────────────────────────────────────────────────────────
# 1Password / secrets / sops
# Do not send these from an agent. Noah runs manually.
# ─────────────────────────────────────────────────────────────

# 1Password sign-in
op signin
# If your shell prints an eval command, run it manually.
# eval $(op signin)

# Edit host secrets. Change host before sending.
$<host>=pc-hylia
sops secrets/$<host>/secrets.yaml

# Edit shared secrets
sops secrets/shared/secrets.yaml

# ─────────────────────────────────────────────────────────────
# Keysync
# Do not send these from an agent. Noah runs manually.
# ─────────────────────────────────────────────────────────────

keysync backup --config keysync.yaml --all
keysync sync --config keysync.yaml --all

# Restore for one host. Change host before sending.
$<restore_host>=pc-hylia
keysync restore --config keysync.yaml --host $<restore_host>
gpg --list-keys --keyid-format long --with-subkey-fingerprint

# Manual backup import fallback. Change paths before sending.
$<keypath>=~/Documents/keys_backup/gpg-backup.asc
$<trustpath>=~/Documents/keys_backup/gpg-trust.txt
gpg --import --import-options restore $<keypath>
gpg --import-ownertrust $<trustpath>

# ─────────────────────────────────────────────────────────────
# DANGER: local keyring reset
# Send these only when intentionally rebuilding local GPG state.
# ─────────────────────────────────────────────────────────────

gpgconf --kill gpg-agent
rm -rf ~/.gnupg
gpg --list-keys

# ─────────────────────────────────────────────────────────────
# keysync development
# ─────────────────────────────────────────────────────────────

cd tools/keysync
go build ./cmd/keysync/
go vet ./...
go test ./...
cd ../..
