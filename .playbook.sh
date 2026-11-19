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
# server-fi: fresh VM provisioning
# Existing Fi must use the agent account/home cutover section below instead.
# Run from ~/Projects/4Nix on Hylia. Nothing here activates Zant's OS.
# The new files must be tracked for a Git flake to include them.
# This stages files only; Noah handles commits.
# ─────────────────────────────────────────────────────────────

git add -- hosts/server-fi/configuration.nix hosts/server-fi/home-common.nix hosts/server-fi/home-noahbalboa66.nix hosts/server-fi/home-agent.nix hosts/server-fi/obsidian.nix home-modules/herdr-core.nix tests/server-fi-config.nix tests/obsidian-hosts.nix tests/obsidian-headless-config.nix tests/server-fi-vault.nix infrastructure/server-zant/server-fi.tf

# Evaluate on Hylia, then copy the derivation and its source dependencies.
# This avoids evaluating Hylia-local flake inputs or using private Git access
# on Zant. nix copy transfers store paths but does not build the Linux image.
# A no-build flake check can print .drv paths without writing them to the
# store. Force uncached evaluation, then check validity before any transfer.
fi_image_drv=$(nix --extra-experimental-features 'nix-command flakes' eval --raw .#packages.x86_64-linux.server-fi-incus-image.drvPath --no-write-lock-file --option builders '' --option eval-cache false)
nix --extra-experimental-features 'nix-command flakes' path-info "$fi_image_drv" > /dev/null && nix --extra-experimental-features 'nix-command flakes' copy --derivation --to ssh-ng://server-zant "$fi_image_drv"

# Run the common module's isolated Linux VM test before provisioning or
# migrating Akkala. It checks multiple vaults, inherited ACLs under umask 077,
# private credentials, per-vault readiness and existing-directory refusal.
# Its fake client never logs in, contacts Obsidian or syncs a real vault.
fi_vault_test_drv=$(nix --extra-experimental-features 'nix-command flakes' eval --raw .#checks.x86_64-linux.server-fi-vault-permissions.drvPath --no-write-lock-file --option builders '' --option eval-cache false)
nix --extra-experimental-features 'nix-command flakes' path-info "$fi_vault_test_drv" > /dev/null && nix --extra-experimental-features 'nix-command flakes' copy --derivation --to ssh-ng://server-zant "$fi_vault_test_drv" && ssh server-zant "nix --extra-experimental-features 'nix-command flakes' build '${fi_vault_test_drv}^*' --no-link --option builders '' --print-build-logs"

# Native x86_64-linux build on Zant. This can take time and use substantial
# disk space. Keep the previous result link until the new build succeeds.
ssh server-zant "mkdir -p /home/noahbalboa66/build/server-fi && nix --extra-experimental-features 'nix-command flakes' build '${fi_image_drv}^*' --out-link /home/noahbalboa66/build/server-fi/result --option builders '' --print-build-logs"
ssh server-zant 'cd /home/noahbalboa66/build/server-fi/result && sha256sum disk.qcow2 metadata.tar.xz' > /tmp/server-fi-image.sha256
mkdir -p result-server-fi
rsync -rtL server-zant:/home/noahbalboa66/build/server-fi/result/ ./result-server-fi/
(cd result-server-fi && shasum -a 256 -c /tmp/server-fi-image.sha256)

# Fi is now enabled in tracked defaults. Preserve intentional local tfvars
# overrides; do not overwrite the file or reset unrelated settings.
# The first apply imported Fi's image but failed during storage conversion.
# Do not replay that saved plan, manually delete volumes, or restart iSCSI.
# The managed pool's 32GiB initial-volume default avoids cache growth for Fi's
# roughly 15GiB image. It does not resize existing guest disks. Fi still gets
# its explicit 256GiB root. Larger future images may need a driver fix.
# Keep Gohdan's old image path for this rollout so no image replacement occurs.
# Run this planning block on Hylia. It makes no live resource changes.
# BEGIN FI STORAGE RETRY PLAN
(
  set -euo pipefail
  umask 077
  cd "$HOME/Projects/4Nix/infrastructure/server-zant"
  plan_dir="$HOME/.local/state/4nix"
  plan_file="$plan_dir/server-fi-storage-fix.tfplan"
  mkdir -p "$plan_dir"
  chmod 700 "$plan_dir"
  if test -e "$plan_file"; then
    printf 'Plan already exists; stop and review it: %s\n' "$plan_file" >&2
    exit 1
  fi
  printf 'Plan destination: %s\n' "$plan_file"
  tofu init -lockfile=readonly
  tofu fmt -check main.tf variables.tf server-fi.tf
  tofu validate
  tofu plan -var="server_gohdan_image_directory=$HOME/Projects/4Nix/result" -out="$plan_file"
  printf '\nSaved plan: %s\n' "$plan_file"
  tofu show -json "$plan_file" | jq '{
    changes: [.resource_changes[]? | select(.change.actions != ["no-op"])
      | {address, actions: .change.actions}],
    pool: [.resource_changes[]? | select(.address == "incus_storage_pool.truenas[0]")
      | .change as $c | {
        before: $c.before.config["volume.size"],
        after: $c.after.config["volume.size"],
        other_changed_keys: (($c.before.config | keys) + ($c.after.config | keys)
          | unique | map(select(. != "volume.size" and ($c.before.config[.] != $c.after.config[.]))))
      }]
  }'
)
# END FI STORAGE RETRY PLAN

# Stop and review the fresh full plan. Expected after the partial apply:
# one in-place pool update adding only volume.size=32GiB, Fi instance create,
# zero destruction and no Gohdan changes. Reject any other actions. Keep a
# recoverable backup of important Gohdan data; its bootstrap image is not one.
# Apply ONLY after this saved plan has been reviewed. Saved-plan apply does
# not ask for another confirmation. This creates and boots Fi.
tofu -chdir="$HOME/Projects/4Nix/infrastructure/server-zant" apply "$HOME/.local/state/4nix/server-fi-storage-fix.tfplan"
incus info zant:server-fi
# Verify SSH/boot, root block-device capacity, and Gohdan health before
# accepting the workaround. No cleanup or storage-service restart is included.

# Direct jump commands work before applying Hylia's Home Manager SSH entry.
ssh -J server-zant noahbalboa66@10.100.0.30
# In the guest administrator session, check the guest agent and disk:
systemctl status incus-agent
findmnt /
lsblk

# Home Manager prepares the same dev bundle used on the workstations for both
# login users. Its existing hooks download Rust's stable toolchain and clone
# the Neovim config. Wait for those activations before checking the tools.
systemctl status home-manager-noahbalboa66 home-manager-agent
git --version
node --version
pnpm --version
python3 --version
go version
rustc --version
dotnet --list-sdks
nvim --version

# Obsidian setup runs only as the private sync account, never as agent.
# Back up the existing 4V2 vault on another device first. Do not let agents
# write into Fi's new vault until the initial download has completed.
# Stop any existing daemon before interactive setup or a one-time sync.
sudo systemctl stop obsidian-4V2
sudo -u obsidian-sync -H env XDG_CONFIG_HOME=/var/lib/obsidian-sync/.config bash

# In the sync-account shell, enter account/E2E credentials only at prompts.
# Select the existing 4V2 remote vault. Do not create a new remote vault.
umask 077
ob login
ob sync-setup --vault 4V2 --path /srv/obsidian/4V2 --device-name server-fi
ob sync-config --path /srv/obsidian/4V2 --mode bidirectional --file-types image,audio,video,pdf,unsupported --configs ''
ob sync --path /srv/obsidian/4V2
# Return to the guest administrator after the first sync completes successfully.
exit

# Only after successful setup and first sync, enable continuous sync on boot.
sudo touch /var/lib/obsidian-sync/4V2.ready
sudo systemctl start obsidian-4V2
systemctl status obsidian-4V2
sudo -u agent test -w /srv/obsidian/4V2
# Credentials remain private. The following test must succeed.
sudo -u agent test ! -r /var/lib/obsidian-sync/.config
ls -ld ~/ObsidianVaults/4V2
# Return to Hylia before the following SSH commands.
exit

# Run setup as the unprivileged agent account. Enter provider credentials only
# in the interactive prompt, never in this file or on a command line.
ssh -t -J server-zant agent@10.100.0.30 'hermes --version'
ssh -t -J server-zant agent@10.100.0.30 'hermes setup'
ssh -t -J server-zant agent@10.100.0.30 'hermes-session'
# Detach with Ctrl-b then d. Re-run the previous command to reconnect.
# Verify a provider call and reconnect before treating the VM as ready.
# tmux survives SSH disconnects, not a VM reboot. Sessions and memory stay
# under /home/agent/.hermes; projects stay under /home/agent/workspace.
# Back up agent state, workspaces and /srv/obsidian/4V2 before updates.
# Sync is not a backup. Snapshots are not configured here.
# Do not delete the VM to roll back. Keep prior guest NixOS generations and
# use the guest boot menu or sudo nixos-rebuild switch --rollback manually.

# ─────────────────────────────────────────────────────────────
# server-fi: agent account/home cutover and Herdr core
# MANUAL ONLY. No switch until Noah confirms the copy is ready and the native
# Linux checks below pass. Keep an administrator SSH session open throughout.
# This updates the installed guest, not its Incus image or OpenTofu resources.
# No T3, Mac package changes, LAN forward or Tailscale setup is included.
# ─────────────────────────────────────────────────────────────

# Phase 1, on Hylia in ~/Projects/4Nix. Review the selected source first.
# Stage the new module/profile and removal of the old profile for flake visibility.
# The agent does not stage or commit files.
git add -A -- home-modules/herdr-core.nix hosts/server-fi tests/server-fi-config.nix tests/server-fi-vault.nix tests/obsidian-hosts.nix
fi_agent_drv=$(nix eval --raw .#nixosConfigurations.server-fi.config.system.build.toplevel.drvPath --no-write-lock-file --option builders '' --option eval-cache false)
fi_core_drv=$(nix eval --raw .#nixosConfigurations.server-fi.config.home-manager.users.agent.home.packages --apply 'packages: (builtins.head (builtins.filter (p: (p.pname or "") == "herdr-core") packages)).drvPath' --no-write-lock-file --option builders '' --option eval-cache false)
fi_agent_policy_drv=$(nix eval --raw .#checks.x86_64-linux.server-fi-config.drvPath --no-write-lock-file --option builders '' --option eval-cache false)
fi_agent_vault_drv=$(nix eval --raw .#checks.x86_64-linux.server-fi-vault-permissions.drvPath --no-write-lock-file --option builders '' --option eval-cache false)
# Run policy and fake-client permissions checks on Zant, where KVM is available.
# Keep transport commands from consuming subsequent pasted/heredoc commands.
printf '%s\n' 'Phase 1: checking Linux policy and vault permissions on Zant.'
nix path-info "$fi_agent_policy_drv" "$fi_agent_vault_drv" > /dev/null && nix copy --derivation --to ssh-ng://server-zant "$fi_agent_policy_drv" "$fi_agent_vault_drv" </dev/null && ssh -n server-zant "nix build '${fi_agent_policy_drv}^*' '${fi_agent_vault_drv}^*' --no-link --option builders '' --print-build-logs" </dev/null
# Build the reviewed closure on Fi itself. This avoids importing unsigned Linux
# build outputs through Hylia or granting either normal user new Nix trust.
# Derivations are evaluated on Hylia; Fi does not evaluate personal flake inputs.
printf '%s\n' 'Phase 1: transferring derivations and building on Fi.'
# Redirect the copy CLI, not Nix's internally managed SSH protocol pipe.
NIX_SSHOPTS='-J server-zant' nix copy --derivation --to ssh-ng://noahbalboa66@10.100.0.30 "$fi_agent_drv" "$fi_core_drv" </dev/null
ssh -n -J server-zant noahbalboa66@10.100.0.30 "mkdir -p /home/noahbalboa66/build/server-fi-agent && nix build '${fi_agent_drv}^*' --out-link /home/noahbalboa66/build/server-fi-agent/result --option builders '' --print-build-logs && nix build '${fi_core_drv}^*' --out-link /home/noahbalboa66/build/server-fi-agent/core --option builders '' --print-build-logs && test -x /home/noahbalboa66/build/server-fi-agent/result/bin/switch-to-configuration && printf 'Fi system: ' && readlink -e /home/noahbalboa66/build/server-fi-agent/result && /home/noahbalboa66/build/server-fi-agent/core/bin/hc --version" </dev/null
printf '%s\n' 'Phase 1 complete. A Fi system store path and hc 0.1.21 must appear above. No rename or switch performed.'
# Expect hc 0.1.21. Stop if any check/build fails. Keep both result links and
# existing NixOS system generations until the migration and rollback are verified.

# Phase 2, on Fi through the administrator session. Copy only, no rename/switch.
ssh -t -J server-zant noahbalboa66@10.100.0.30
# If you have already copied the data, do not rerun this preparation block.
# Keep all Hermes processes stopped until cutover; a live SQLite copy is unsafe.
# This deliberately refuses an existing destination rather than merging state.
# BEGIN FI AGENT COPY
(
  set -euo pipefail
  umask 077
  fail() { printf '%s\n' "$*" >&2; exit 1; }
  [[ $(hostname -s) == server-fi && $(id -un) == noahbalboa66 && $HOME == /home/noahbalboa66 ]] || fail 'Stop: run on Fi as noahbalboa66.'
  [[ $(id -u hermes) == 1000 && $(id -g hermes) == 100 ]] || fail 'Stop: old identity changed.'
  [[ $(getent passwd hermes | cut -d: -f6) == /var/lib/hermes ]] || fail 'Stop: old home changed.'
  if getent passwd agent >/dev/null; then fail 'Stop: agent already exists.'; fi
  stage="$HOME/.local/state/fi-agent-migration"
  [[ ! -e $stage && ! -L $stage && ! -e /home/agent && ! -L /home/agent ]] || fail 'Stop: staging or destination exists; review without deleting it.'
  for name in .hermes workspace; do
    sudo test -d "/var/lib/hermes/$name" && sudo test ! -L "/var/lib/hermes/$name" || fail "Stop: expected a real source directory: $name"
  done
  read -r -p 'Save all agent work. Type STOP-AND-COPY to end Hermes sessions and copy: ' answer < /dev/tty
  [[ $answer == STOP-AND-COPY ]] || fail 'Cancelled.'
  sudo loginctl disable-linger hermes
  sudo systemctl stop home-manager-hermes.service
  if sudo loginctl show-user hermes >/dev/null 2>&1; then sudo loginctl terminate-user hermes; fi
  if sudo pgrep -u 1000 >/dev/null; then fail 'Stop: UID 1000 still has processes. Do not copy live state.'; fi
  mkdir -p "$HOME/.local/state"
  mkdir -m 0700 "$stage"
  archive="$stage/hermes-home.tar"
  # The shell creates this 0600 archive as Noah; tar records original UID/GID.
  sudo tar --acls --xattrs --numeric-owner -C /var/lib/hermes -cf - .hermes workspace > "$archive"
  [[ $(stat -c %u:%a "$archive") == "$(id -u):600" ]] || fail 'Stop: archive must be private and owned by Noah.'
  sudo install -d -m 0700 -o 1000 -g 100 /home/agent
  sudo tar --acls --xattrs --numeric-owner --same-owner -xpf "$archive" -C /home/agent
  sudo tar --compare --numeric-owner -f "$archive" -C /home/agent
  printf '%s\n' "Private Noah archive: $archive" 'Restored into /home/agent with original ownership. Login/home metadata are unchanged.' 'Keep Hermes stopped and both backups private. Report copy readiness; do not switch yet.'
)

# END FI AGENT COPY
# Do not copy Nix profile symlinks or the shared vault. Review any other manual
# tool state privately. Existing linked Git worktrees and absolute old-home
# references need deliberate repair before use, not a blind text replacement.
# If abandoning the copy phase, the old account can be used again after Noah
# deliberately restores its linger setting with sudo loginctl enable-linger hermes.
# The Noah-owned staging archive contains credentials. Keep it private and out of
# Git, Obsidian and the Nix store. Retain it and the old home through verification.

# Phase 3, HOLD. Run only after explicit copy readiness and native check review.
# Stay in the Fi administrator session. No rebuild or source evaluation here:
# activate only the exact closure already built in Phase 1.
# BEGIN FI AGENT CUTOVER
sudo bash <<'FI_AGENT_CUTOVER'
set -euo pipefail
umask 077
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $(hostname -s) == server-fi ]] || fail 'Stop: expected server-fi.'
[[ $(id -u hermes) == 1000 && $(id -g hermes) == 100 ]] || fail 'Stop: old identity changed.'
[[ $(getent passwd hermes | cut -d: -f6) == /var/lib/hermes ]] || fail 'Stop: old home changed.'
if getent passwd agent >/dev/null; then fail 'Stop: agent already exists.'; fi
[[ -d /home/agent && ! -L /home/agent ]] || fail 'Stop: new home is absent or a symlink.'
[[ $(stat -c %u:%g:%a /home/agent) == 1000:100:700 ]] || fail 'Stop: new home must be UID 1000, GID 100 and mode 0700.'
if pgrep -u 1000 >/dev/null; then fail 'Stop: old account still has processes; stop them before cutover.'; fi
for name in .hermes workspace; do
  [[ -d /home/agent/$name && ! -L /home/agent/$name ]] || fail "Stop: new $name is absent or a symlink."
  [[ $(stat -c %u:%a /home/agent/$name) == 1000:700 ]] || fail "Stop: new $name must be owned by UID 1000 with mode 0700."
  diff -qr --no-dereference "/var/lib/hermes/$name" "/home/agent/$name" >/dev/null || fail "Stop: source/copy changed for $name."
done
new_system=$(readlink -e /home/noahbalboa66/build/server-fi-agent/result) || fail 'Stop: no complete system build at /home/noahbalboa66/build/server-fi-agent/result. Run Phase 1; no account change made.'
old_system=$(readlink -e /run/current-system) || fail 'Stop: current system path could not be resolved; no account change made.'
[[ $new_system == /nix/store/* && -x $new_system/bin/switch-to-configuration ]] || fail 'Stop: new closure is unavailable.'
[[ $old_system == /nix/store/* && -x $old_system/bin/switch-to-configuration ]] || fail 'Stop: old closure is unavailable.'
[[ $(readlink -f /nix/var/nix/profiles/system) == "$old_system" ]] || fail 'Stop: running system and boot profile differ; review first.'
[[ $new_system != "$old_system" ]] || fail 'Stop: new and old closures are identical.'
state=/var/lib/fi-agent-cutover
[[ ! -e $state && ! -L $state ]] || fail 'Stop: previous cutover record exists; review it, do not overwrite.'
read -r -p 'Native checks passed and copy verified? Type SWITCH-AGENT to rename and activate: ' answer < /dev/tty
[[ $answer == SWITCH-AGENT ]] || fail 'Cancelled.'
if pgrep -u 1000 >/dev/null; then fail 'Stop: old account became active while awaiting confirmation.'; fi
install -d -m 0700 -o root -g root "$state"
printf '%s\n' "$old_system" > "$state/previous-system"
printf '%s\n' "$new_system" > "$state/new-system"
printf '%s\n' 'Renaming the login and selecting the new system profile.'
usermod --login agent --home /home/agent hermes
nix-env --profile /nix/var/nix/profiles/system --set "$new_system" </dev/null
printf '%s\n' 'Activating the built system. Keep the administrator session open.'
"$new_system/bin/switch-to-configuration" switch </dev/null
[[ $(id -u agent) == 1000 && $(getent passwd agent | cut -d: -f6) == /home/agent ]] || fail 'Stop: new identity did not match.'
runuser -u agent -- test -w /home/agent/workspace || fail 'Stop: agent cannot write its workspace.'
runuser -u agent -- test -w /srv/obsidian/4V2 || fail 'Stop: agent cannot write the shared vault.'
runuser -u agent -- test ! -r /var/lib/obsidian-sync/.config || fail 'Stop: agent can read private sync state.'
[[ $(readlink -f /home/agent/ObsidianVaults/4V2) == /srv/obsidian/4V2 ]] || fail 'Stop: shared vault link is incorrect.'
systemctl is-active --quiet home-manager-agent.service || fail 'Stop: Home Manager activation is not active; keep the administrator session open and report the error.'
printf '%s\n' 'Cutover complete. Keep this administrator connection open and verify a second agent SSH login.' 'Old home and exact rollback closure remain retained; do not remove them or run GC yet.'
FI_AGENT_CUTOVER
# END FI AGENT CUTOVER

# On failure, stop and keep the administrator connection open. Never blindly
# overwrite newer conversations or refreshed credentials with the old copy.
# Save/reconcile any new state privately or plan to reauthenticate first.
# This rollback leaves /home/agent intact for recovery, not automatic merging.
# BEGIN FI AGENT ROLLBACK
sudo bash <<'FI_AGENT_ROLLBACK'
set -euo pipefail
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $(hostname -s) == server-fi ]] || fail 'Stop: expected server-fi.'
[[ $(id -u agent) == 1000 ]] || fail 'Stop: expected the migrated agent account.'
if getent passwd hermes >/dev/null; then fail 'Stop: hermes already exists.'; fi
[[ -d /var/lib/hermes && ! -L /var/lib/hermes ]] || fail 'Stop: old home is unavailable.'
[[ $(stat -c %u:%g:%a /var/lib/hermes) == 1000:100:700 ]] || fail 'Stop: old home metadata changed.'
old_system=$(< /var/lib/fi-agent-cutover/previous-system)
[[ $old_system == /nix/store/* && -x $old_system/bin/switch-to-configuration ]] || fail 'Stop: retained old closure is unavailable.'
read -r -p 'New state saved/reconciled? Type ROLLBACK-AGENT to stop agents and restore the old identity: ' answer < /dev/tty
[[ $answer == ROLLBACK-AGENT ]] || fail 'Cancelled.'
loginctl disable-linger agent
# Activation may have failed before the new unit was installed.
if systemctl cat home-manager-agent.service >/dev/null 2>&1; then systemctl stop home-manager-agent.service; fi
if loginctl show-user agent >/dev/null 2>&1; then loginctl terminate-user agent; fi
if pgrep -u 1000 >/dev/null; then fail 'Stop: UID 1000 still has processes.'; fi
usermod --login hermes --home /var/lib/hermes agent
nix-env --profile /nix/var/nix/profiles/system --set "$old_system" </dev/null
"$old_system/bin/switch-to-configuration" switch </dev/null
printf '%s\n' 'Old identity and exact previous system restored. Both homes remain; verify state before restarting Hermes.'
FI_AGENT_ROLLBACK
# END FI AGENT ROLLBACK

# After successful cutover, open a second login from Hylia before closing admin.
ssh -t -J server-zant agent@10.100.0.30 'printf "HOME=%s\n" "$HOME"; id; hc --version; hermes --version'
# On Hylia as the normal Mac user, use the tested SSH alias as agent.
# Native machine-add login failed despite working direct SSH; this bypasses
# Herdr's separate shared-login helper. SSH config supplies the Zant jump.
# This connection carries protocol stdin; do not add SSH -n inside --via.
# Decline any remote core installer/updater because Fi's package is Nix-managed.
# First registration only; the current fi profile is already connected.
# The GUI-started core needs the terminal's working SSH-agent environment.
# This selects the local socket for both SSH hops, without agent forwarding.
if [ -S "${SSH_AUTH_SOCK:-}" ]; then
  "$HOME/.local/bin/herdr-core" machine add --name fi \
    --via "env SSH_AUTH_SOCK=$(printf '%q' "$SSH_AUTH_SOCK") ssh -T -oBatchMode=yes agent@server-fi"
else
  printf '%s\n' 'No SSH-agent socket is set in this terminal.'
fi
# In the GUI select fi, create a space at /home/agent/workspace, and run hermes
# directly in its terminal, not the hermes-session tmux wrapper.
# No automatic mobile setup or rich Hermes Inbox status is promised here.

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
