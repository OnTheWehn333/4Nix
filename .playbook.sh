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

# NixOS servers
nh os switch . -H server-tenoko
nh os build . -H server-tenoko
nh os test . -H server-tenoko
nh os boot . -H server-tenoko

nh os switch . -H server-zant
nh os build . -H server-zant
nh os test . -H server-zant
nh os boot . -H server-zant

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
# server-zant Incus client enrollment
# Run the trust command once, then paste its token into `incus remote add`.
# Use server-zant's LAN address if Tailscale MagicDNS is unavailable.
# ─────────────────────────────────────────────────────────────

ssh server-zant 'incus config trust add pc-hylia'
incus remote add zant https://server-zant:8443
incus remote switch zant
incus list

# ─────────────────────────────────────────────────────────────
# server-gohdan: prepare the dedicated image directory
# Run from ~/Projects/4Nix on Hylia before the next OpenTofu plan.
# Use this only if result/ contains the known Gohdan bootstrap image.
# Otherwise rebuild server-gohdan-incus-image using Fi's build workflow below,
# with Gohdan's output name and result-server-gohdan as the local destination.
# Stop if a command fails or the checksum comparison reports a mismatch.
# The copy does not overwrite existing files. Keep the original result/ intact.
# Matching checksums verify the copy, not which VM the image belongs to.
# ─────────────────────────────────────────────────────────────

gohdan_checksums=$(mktemp "${TMPDIR:-/tmp}/server-gohdan-image.XXXXXX")
(cd result && shasum -a 256 disk.qcow2 metadata.tar.xz) > "$gohdan_checksums"
mkdir -p result-server-gohdan
cp -n result/disk.qcow2 result/metadata.tar.xz result-server-gohdan/
(cd result-server-gohdan && shasum -a 256 -c "$gohdan_checksums")

# Review the complete OpenTofu plan after this path change. Reject any VM
# replacement or deletion; preparing artifacts does not update the guest OS.

# ─────────────────────────────────────────────────────────────
# pc-akkala: migrate headless Obsidian to the shared system module
# This is a manual, one-time cutover, not an agent-run script.
# Use the reviewed source on Akkala. Do not activate before the native Linux
# VM test above passes. Zant can run it if WSL has no usable KVM support.
# Review every step. Do not paste this entire playbook into a shell.
# Pause editors, agents and other vault writers on ALL devices through first
# sync. Confirm both old daemons report Fully synced after the last edits,
# with no pending errors, before stopping them. A fresh client has no old
# deletion history; copying stale contents can resurrect deleted notes.
# Make a separate recoverable backup on another device before this cutover.
# Run in Bash on pc-akkala as noahbalboa66, not on Hylia or in a vault folder.
# ─────────────────────────────────────────────────────────────

cd ~/projects/4Nix
git status --short
# Stage the new test/Fi files listed in the Fi section before Git-flake use.
# Review the full dirty checkout, including unrelated work, before building.
nix flake check --no-build --all-systems --no-write-lock-file --option builders ''
nh os build . -H pc-akkala

# Inspect current sync configuration without displaying authentication files.
# Expected old config directory is .obsidian. Stop and adjust the lock exclusion
# below if either vault uses a custom config directory. Do not dump .config.
ob sync-status --path "$HOME/ObsidianVaults/4Vault"
ob sync-status --path "$HOME/ObsidianVaults/4V2"
systemctl show obsidian-4Vault obsidian-4V2 -p User -p WorkingDirectory
df -h "$HOME" /srv
du -sh "$HOME/ObsidianVaults/4Vault" "$HOME/ObsidianVaults/4V2"

# Keep this private directory's printed path. It holds the rollback closure,
# full backup copies and the original directories. Reuse that exact path if
# continuing in another shell. Budget disk space for both backup and new copy.
umask 077
mkdir -p "$HOME/.local/state"
obs_migration=$(mktemp -d "$HOME/.local/state/obsidian-migration.XXXXXX")
printf 'Migration and rollback directory: %s\n' "$obs_migration"

# BEGIN AKKALA OBSIDIAN PRESERVE
(
  set -euo pipefail
  [[ $(hostname -s) == pc-akkala && $USER == noahbalboa66 ]]
  [[ -d $obs_migration && ! -e $obs_migration/previous-system ]]
  # This handoff assumes a first cutover, not existing dedicated sync state.
  sudo test ! -e /var/lib/obsidian-sync
  for vault in 4Vault 4V2; do
    src="$HOME/ObsidianVaults/$vault"
    [[ -d $src && ! -L $src ]]
    [[ ! -e /srv/obsidian/$vault && ! -L /srv/obsidian/$vault ]]
    # Do not silently skip symlinks, special files or a nested mount.
    [[ -z $(find "$src" ! -type d ! -type f -print -quit) ]]
    [[ -z $(findmnt -rn -o TARGET | awk -v root="$src" '$0 == root || index($0, root "/") == 1') ]]
  done
  old_system=$(readlink -f /run/current-system)
  printf '%s\n' "$old_system" > "$obs_migration/previous-system"
  nix-store --realise "$old_system" --add-root "$obs_migration/previous-system-root" --indirect
  # A runtime condition holds old AND new units across activation. Runtime
  # masks alone can lose to NixOS's generated unit links under /etc.
  sudo test ! -e /run/obsidian-cutover-hold
  sudo touch /run/obsidian-cutover-hold
  for vault in 4Vault 4V2; do
    dropin="/run/systemd/system/obsidian-$vault.service.d/99-cutover-hold.conf"
    sudo test ! -e "$dropin"
    sudo mkdir -p "${dropin%/*}"
    printf '[Unit]\nConditionPathExists=!/run/obsidian-cutover-hold\n' | sudo tee "$dropin" > /dev/null
  done
  sudo systemctl daemon-reload
  sudo systemctl stop obsidian-4Vault.service obsidian-4V2.service
  mkdir -p "$obs_migration/backup" "$obs_migration/originals"
  for vault in 4Vault 4V2; do
    mkdir "$obs_migration/backup/$vault"
    rsync -a -- "$HOME/ObsidianVaults/$vault/" "$obs_migration/backup/$vault/"
    # A checksum comparison must have no differences before moving originals.
    [[ -z $(rsync -nrc --delete --itemize-changes -- "$HOME/ObsidianVaults/$vault/" "$obs_migration/backup/$vault/") ]]
  done
  # Neither copy nor backup deletes source data. Moving these originals aside
  # is necessary because activation deliberately refuses real vault folders.
  for vault in 4Vault 4V2; do
    mv -T -- "$HOME/ObsidianVaults/$vault" "$obs_migration/originals/$vault"
  done
)
# END AKKALA OBSIDIAN PRESERVE

# Stop on any prior failure. Do not switch if backups or the native test failed.
# The new markers do not exist yet. The runtime hold also remains in place.
# Do not reboot midway through cutover; runtime drop-ins do not survive reboot.
nh os switch . -H pc-akkala
systemctl status home-manager-noahbalboa66

# BEGIN AKKALA OBSIDIAN RESTORE CONTENTS
(
  set -euo pipefail
  [[ $(hostname -s) == pc-akkala && $USER == noahbalboa66 ]]
  [[ -f $obs_migration/previous-system ]]
  for vault in 4Vault 4V2; do
    dest="/srv/obsidian/$vault"
    [[ -d $dest && ! -L $dest ]]
    [[ $(readlink -f "$HOME/ObsidianVaults/$vault") == "$dest" ]]
    sudo test ! -e "/var/lib/obsidian-sync/$vault.ready"
    # A nonempty target means this is not the expected first cutover. Stop.
    [[ -z $(sudo find "$dest" -mindepth 1 -maxdepth 1 -print -quit) ]]
    # Copy contents, not the old account's .config authentication/state.
    # The pinned client keeps credentials, database and logs outside the vault.
    # Exclude its old in-vault lock directory. Preserve .obsidian settings as
    # local files, but do not sync settings/plugins to other devices.
    # No -A: new directories inherit the destination's default ACLs. Normalize
    # owner/group and shared modes, preserving executable files but no set-ID.
    sudo rsync -rtpog --chown="obsidian-sync:obsidian-vault-$vault" \
      --chmod='D2770,Fu+rwX,Fg+rwX,Fo-rwx,Fu-s,Fg-s' \
      --exclude='/.obsidian/.sync.lock' -- "$obs_migration/backup/$vault/" "$dest/"
    sudo -u noahbalboa66 test -w "$dest"
    sudo -u obsidian-sync test -w "$dest"
  done
  sudo -u noahbalboa66 test ! -r /var/lib/obsidian-sync
)
# END AKKALA OBSIDIAN RESTORE CONTENTS

# In a fresh WSL login your new supplementary groups take effect. Until then,
# the sudo -u checks above use the updated account groups. Do not resume edits.
# Enter a shell explicitly as the non-login sync account. Credentials are
# entered only at prompts. Do not copy the old user's token or sync database.
sudo -u obsidian-sync -H env XDG_CONFIG_HOME=/var/lib/obsidian-sync/.config bash
umask 077
ob login
# Select existing remote vaults. If names are ambiguous, use their IDs.
# Never create a new remote vault or choose mirror-remote for this migration.
ob sync-setup --vault 4Vault --path /srv/obsidian/4Vault --device-name pc-akkala
ob sync-config --path /srv/obsidian/4Vault --mode bidirectional --file-types image,audio,video,pdf,unsupported --configs ''
ob sync --path /srv/obsidian/4Vault
ob sync-setup --vault 4V2 --path /srv/obsidian/4V2 --device-name pc-akkala
ob sync-config --path /srv/obsidian/4V2 --mode bidirectional --file-types image,audio,video,pdf,unsupported --configs ''
ob sync --path /srv/obsidian/4V2
# Exit only after both first syncs complete successfully. Review any conflicts.
exit

# Back in the administrator shell, release the gates only after successful
# setup. For a partial setup, release only the vault that passed first sync.
sudo touch /var/lib/obsidian-sync/4Vault.ready /var/lib/obsidian-sync/4V2.ready
sudo rm -- /run/obsidian-cutover-hold
sudo systemctl start obsidian-4Vault.service obsidian-4V2.service
systemctl status obsidian-4Vault obsidian-4V2
ls -ld "$HOME/ObsidianVaults/4Vault" "$HOME/ObsidianVaults/4V2"
# Start a fresh WSL login before editing. Confirm a harmless test note and its
# removal reach another device. Keep all backups until the cutover is accepted.
# The original account's old credential state is untouched, never shared.
# Review revocation/cleanup separately after acceptance. Sync is not a backup.

# OPTIONAL ROLLBACK, NOT THE NEXT CUTOVER STEP
# Pause all edits again. Retain and reconcile any post-cutover edits before
# resuming old sync. Restoring local configuration does not undo remote edits.
# Reuse the recorded obs_migration directory, not a newly created directory.
# BEGIN AKKALA OBSIDIAN ROLLBACK
(
  set -euo pipefail
  [[ $(hostname -s) == pc-akkala && $USER == noahbalboa66 ]]
  old_system=$(<"$obs_migration/previous-system")
  [[ $old_system == /nix/store/* && -x $old_system/bin/switch-to-configuration ]]
  # Reinstall the hold even if a reboot removed the original runtime drop-ins.
  sudo touch /run/obsidian-cutover-hold
  for vault in 4Vault 4V2; do
    dropin="/run/systemd/system/obsidian-$vault.service.d/99-cutover-hold.conf"
    sudo mkdir -p "${dropin%/*}"
    printf '[Unit]\nConditionPathExists=!/run/obsidian-cutover-hold\n' | sudo tee "$dropin" > /dev/null
  done
  sudo systemctl daemon-reload
  sudo systemctl stop obsidian-4Vault.service obsidian-4V2.service
  mkdir -p "$obs_migration/retired-readiness" "$obs_migration/retired-links"
  for vault in 4Vault 4V2; do
    link="$HOME/ObsidianVaults/$vault"
    if sudo test -e "/var/lib/obsidian-sync/$vault.ready"; then
      sudo test ! -e "$obs_migration/retired-readiness/$vault.ready"
      sudo mv -- "/var/lib/obsidian-sync/$vault.ready" "$obs_migration/retired-readiness/$vault.ready"
    fi
    if [[ -d $obs_migration/originals/$vault ]]; then
      if [[ -L $link ]]; then
        [[ ! -e $obs_migration/retired-links/$vault && ! -L $obs_migration/retired-links/$vault ]]
        mv -T -- "$link" "$obs_migration/retired-links/$vault"
      fi
      [[ ! -e $link && ! -L $link ]]
      mv -T -- "$obs_migration/originals/$vault" "$link"
    else
      # A failed cutover may have stopped before moving this original.
      [[ -d $link && ! -L $link ]]
    fi
  done
  # Restore the exact recorded closure, not an assumed previous generation.
  sudo nix-env --profile /nix/var/nix/profiles/system --set "$old_system"
  sudo "$old_system/bin/switch-to-configuration" switch
)
# END AKKALA OBSIDIAN ROLLBACK

# Only after reviewing/reconciling old originals with the retained /srv copies:
sudo rm -- /run/obsidian-cutover-hold
sudo systemctl start obsidian-4Vault.service obsidian-4V2.service
# Do not delete /srv copies, backups or the GC root during rollback.

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
