# server-zant Incus infrastructure

OpenTofu owns Incus API resources on `server-zant`, including the server API
listener, networks, profiles, storage pools, and eventual instances. Nix owns
the host OS, Incus daemon and packages, UI package, firewall prerequisites,
Open-iSCSI, `truenas_incus_ctl`, and the rendered SOPS configuration.

## Safety boundaries

- Do not apply a plan that deletes or replaces `4Ubuntu`, its root volume, or
  the `truenas` pool.
- The original XCP-ng VHD is immutable recovery input. Convert a separate
  working copy and verify the original checksum afterward.
- The old XCP-ng iSCSI LUN and target are out of scope.
- `prevent_destroy` protects the network, profiles, and future storage pool.
- The `4Ubuntu` instance is intentionally absent from this configuration until
  it has been restored and boot-tested.

## Temporary Hylia-local state

Hylia is the infrastructure control workstation. Its Incus client has a
TLS-authenticated remote named `zant`, and the OpenTofu provider uses that
remote rather than Zant's local Unix socket.

The current state has been copied to Hylia and remains on OpenTofu's local
backend temporarily. State is ignored by Git. Run routine commands from Hylia:

```bash
cd ~/Projects/4Nix/infrastructure/server-zant
tofu init -lockfile=readonly
tofu fmt -check
tofu validate
tofu plan
```

The one-time ownership transition is complete. The state owns the Incus server
API setting, `incusbr0`, the `default` and `4ubuntu-vm` profiles, and the
`truenas` pool. A normal plan must report no changes before new resources are
added. Do not repeat the original imports against another state.

On a genuinely fresh host with no Incus API objects, use a separate reviewed
bootstrap procedure rather than reusing the current state.

## TrueNAS storage gate

The current TrueNAS pool has passed its API, iSCSI, and dataset checks and is
enabled by default. On a fresh replacement host, temporarily set
`enable_truenas_pool = false` in an untracked `terraform.tfvars` before the
first plan. Then confirm API access and that the intended child dataset does
not exist:

```bash
sudo truenas_incus_ctl \
  --config-file /run/secrets/rendered/truenas-incus-ctl-config \
  --config truenas \
  dataset ls spirit-spring

sudo truenas_incus_ctl \
  --config-file /run/secrets/rendered/truenas-incus-ctl-config \
  --config truenas \
  dataset ls spirit-spring/server-zant
```

The intended Incus pool is:

```text
Incus pool:              truenas
TrueNAS source:          spirit-spring/server-zant
TrueNAS portal:          ID 1 (0.0.0.0:3260)
Initiator group:         ID 2 (`server-zant`)
Local initiator IQN:     iqn.2026-06.dev.4nix:server-zant
Root size:               256GiB
```

Confirm that `spirit-spring/server-zant` does not exist or is empty. Keep
`truenas.force_reuse=false`; it prevents accidental adoption of an existing
nonempty dataset.

Before running `share iscsi setup --test`, verify that TrueNAS initiator group
ID `2` has comment `server-zant` and allows only
`iqn.2026-06.dev.4nix:server-zant`. Portal ID `1` is the existing
`0.0.0.0:3260` listener and can serve both old and new targets. Numeric IDs
prevent the helper from creating replacement portal or initiator objects when a
name or address does not match.

After those objects are verified, test the exact selections:

```bash
sudo truenas_incus_ctl \
  --config-file /run/secrets/rendered/truenas-incus-ctl-config \
  --config truenas \
  share iscsi setup --test \
  --portal 1 \
  --initiator 2
```

When the API, iSCSI test, and dataset check all pass, remove the temporary
`enable_truenas_pool = false` override or change it to `true`. Then review
`tofu plan` before applying. Enabling the pool also adds the root disk device
to the `default` profile.

OpenTofu and Incus state contain only the config profile name `truenas`, not
the API key or rendered file path. Nix places a wrapper in the Incus service
PATH that injects the root-only rendered `--config-file` when the driver invokes
`truenas_incus_ctl`.

## Initial volume size

The managed `truenas` pool sets `volume.size = 32GiB` for new volumes without
an explicit size, including optimized VM image caches. This does not resize
existing VM disks. Explicit guest root devices remain 256 GiB.

This is a workaround for the Incus 7.0.1 TrueNAS raw-block growth path. An
unset default starts image caches at 10 GiB; growing a larger image can leave
the active iSCSI device reporting its old capacity before QEMU conversion.
Starting at 32 GiB avoids that growth for Fi's approximately 15 GiB image.
Images larger than 32 GiB still need investigation until the driver is fixed.

Apply this setting only through a reviewed full plan. Expect an in-place pool
configuration update, not pool replacement or existing-volume resizing. After
a failed create, use a fresh plan against current state, never the old saved
plan.

## VM image paths and overrides

Keep VM image artifacts in separate directories under the repo root:

- Gohdan uses `result-server-gohdan/`.
- Fi uses `result-server-fi/`.

Each directory contains `disk.qcow2` and `metadata.tar.xz`. The corresponding
image-directory variables default to these paths, resolved from
`infrastructure/server-zant` on Hylia. Keep `terraform.tfvars` for intentional
overrides; do not repeat the image paths, addresses or other tracked defaults.
Fi is enabled in the tracked defaults after its initial image was prepared.
No enable override is required unless local tfvars intentionally disables it.

Gohdan previously used the generic `result/` directory. Before the next plan,
copy the existing artifacts without overwriting files in
`result-server-gohdan/` and compare checksums, but only if you know they are
Gohdan's image. The copy preserves `result/` and does not overwrite existing
files. Matching checksums establish copy integrity, not image provenance.
For future Gohdan builds, use the `server-gohdan-incus-image` output with the
same Hylia-evaluation and Zant-build workflow as Fi, and transfer the artifacts
to `result-server-gohdan/`, not `result/`.

Review the full live plan after changing an image source path. It may propose
an image-resource change; this is not permission to replace an existing VM.
Both VM instances ignore source-image changes and must retain their disks.
Do not remove lifecycle protections to make a plan apply. For the current
Fi-only rollout, keep `server_gohdan_image_directory` set to the exact old
absolute path for the plan. Preparing its dedicated directory does not
require replacing its existing image resource. That path migration is deferred.

## Server-fi agent VM

`server-fi.tf` defines a NixOS VM for AI agents. Its defaults are 4 vCPUs,
8 GiB RAM and a 256 GiB TrueNAS-backed root disk. `boot.autostart` keeps the VM
running after an Incus host restart. `enable_server_fi` now defaults to `true`;
keep the verified local image artifacts available for infrastructure plans.

Fi uses the default address `10.100.0.30` on `incusbr0`, matching Hylia's SSH
entry. Build and verify the image before provisioning. The guest accepts SSH
only from Zant's bridge address, using the existing Hylia/Akkala public keys.
There is no LAN forward, public listener or messaging gateway. The existing
NAT bridge still permits outbound LAN access; this is not network isolation.

Evaluate `.#server-fi-incus-image` on Hylia, build its derivation on Zant
using x86_64 Linux, and transfer the image back to Hylia. Copying the derivation avoids evaluating
Hylia-local flake paths and private Git inputs on Zant. OpenTofu expects the
resulting `disk.qcow2` and `metadata.tar.xz` under `../../result-server-fi`.
Review the whole plan before applying. Only Fi's image, profile and instance
should be new. The current image-cache workaround retry also expects one
in-place pool default update. Existing resources must not be replaced or deleted.

SSH as `noahbalboa66` for administration and `agent` for agent work. The shared
agent account retains UID 1000 and uses `/home/agent`. It has no sudo or
container-runtime group membership, and SSH agent/TCP forwarding stays disabled.
Do not run agents as the administrator or forward administrative credentials.

Do not use the routine Fi switch on a guest still using the old `hermes`
account. Plan the account and home migration first. Build and test the
new closure first, stop Hermes, privately copy the complete `.hermes/` and
`workspace/` directories, then wait for explicit copy readiness before the
login/home rename and activation. Keep `/var/lib/hermes` as private rollback
data. Do not recreate the VM or re-import its bootstrap image for this update.
Record the exact previous closure and a rollback procedure before migration. Review
absolute old-home references and linked Git worktrees separately; do not blindly
rewrite configuration, history or database files.

Each login account has an explicit Home Manager profile under `hosts/server-fi`:
`home-noahbalboa66.nix` for the operator and `home-agent.nix` for agent tools.
Their Git identities and signing settings are defined in those files, without
username conditionals. Both import `home-common.nix` for the same development
bundle as Hylia and Akkala, plus Node.js 22, pnpm and Java. Git/GitHub CLI, Neovim, Python,
Rust, .NET, Go and build tools are included. Existing activation hooks download
the stable Rust toolchain and prepare the personal Neovim configuration.
Git signing is disabled until Fi has its own signing identity. Agent commits
use `Agent <agent@server-fi>`, not the administrator's author identity.

Hermes is pinned through its upstream flake. Native Nix support is best-effort,
so a native build, first boot and provider call are required before use. Setup
stores credentials and state under `/home/agent/.hermes`; projects belong under
`/home/agent/workspace`. Neither directory belongs in Git or an image derivation.
For the migration, copy the entire stopped Hermes state directory, including
hidden files and any SQLite sidecars, not only config.yaml or state.db. Preserve
private permissions and original data. Other tools' manually managed state may
need separate migration or login. Home Manager recreates its declared files and
vault link; do not copy old Nix profile symlinks or duplicate the shared vault.
New-home Rust/Neovim activation hooks may download their existing toolchain/editor
configuration again. No SOPS payload or recipient is needed for Hermes.

Herdr desktop is installed manually on Hylia, outside Nix. Fi uses the reusable
`home-modules/herdr-core.nix` package, pinned to official core 0.1.21 for Linux
x86_64 and installed only in the agent profile. Core starts on demand and keeps
terminals alive after disconnect while the guest stays running. It uses the
existing agent linger setting, not a new boot-started agent service. Updates to
Fi's core go through Nix, not `hc update` or Herdr's remote installer.

After the cutover, verify ordinary SSH as `agent` and `hc --version`, then add
`agent@server-fi` in the Mac GUI's machine settings. The existing Hylia SSH host
entry supplies the Zant jump. No GUI runs on Fi. Start `hermes` directly in a core
terminal; the optional `hermes-session` wrapper puts tmux between core and Hermes
and is for separate tmux use. Rich Hermes Inbox status is not established for
this pinned version; ordinary terminal access is the first target. Keep the working `SSH_AUTH_SOCK` in the existing Herdr profile's local SSH transport environment.
Mobile connectivity, LAN forwards and Tailscale setup remain separate work.

T3 Code is an additional structured-chat frontend, not a replacement for Herdr.
Fi declares a Nix-owned `t3-code.service` running as `agent`, starting at boot and
listening only on `127.0.0.1:3773`. The service explicitly runs the headless `t3`
entry point. Its maintained T3 0.1.8 package includes desktop assets, but no GUI
is launched on Fi. A separate pinned `nixpkgs-t3` source supplies that package
and Pi 1.5.2 without updating the shared unstable input. Codex and the T3 wrapper's
GitHub helper default are disabled. Pi and Hermes are available on the service's
explicit runtime PATH; no interactive shell initialization is required.

Before first activation, run the `t3-code-config` and `t3-code-service` checks
on Linux. Stop if Fi already has T3 state or another service on port 3773.
The routine deployment command does not check those preconditions. State stays private in `/home/agent/.t3`;
Pi authentication is separate under its own home state. Service startup stdout
is discarded because it can contain pairing details. The unprivileged launcher
writes application stderr to `.t3/logs/service.stderr.log`, not the journal.
The root-owned `/etc/t3code/policy.json` disables self-updates, provider update
checks, automatic thread continuation, T3 Connect, telemetry and browser bootstrap.
Keep T3, Pi and Hermes updates in Nix. Do not use the app's Update all, the vendor
service installer or desktop-managed SSH runtime downloads for this backend.

For this trial, Noah keeps one ordinary SSH tunnel open from Hylia through the
existing administrator `server-fi` alias. It forwards Hylia loopback port 13773
to Fi loopback port 3773. The Mac app pairs with that local endpoint. The tunnel
needs the administrator's existing forwarding permission; agent forwarding
restrictions and firewall rules stay unchanged. T3 and its provider children
still run as `agent`, never as the administrator. Pairing links are secrets.
Generate and enter them privately, not in Git, logs, issue reports or chat.

The existing Mac 0.1.7 client and backend 0.1.8 declare orchestration protocol 2;
actual pairing and provider use still require a smoke test. Configure Pi as a
native provider and Hermes as the local executable `hermes` with argument `acp`
on the Fi environment. They keep their own credentials, sessions and memory.
T3-managed Pi child threads remain visible and resumable in the shared UI. A
Hermes-to-Pi dispatch through existing T3 task controls needs an explicit trial;
no custom orchestrator or automatic conversation import is installed here.

Obsidian Headless syncs the existing `4V2` remote vault bidirectionally into
`/srv/obsidian/4V2`. Both accounts have a `~/ObsidianVaults/4V2` link. The agent
has read/write access, so edits and deletions can propagate to other devices.
Back up the existing vault before connecting Fi and finish its first download
before letting agents write notes. Settings and plugin syncing are disabled;
all configured attachment categories, including unsupported types, are enabled.

The `obsidian-sync` account keeps login and encryption state under its private
`/var/lib/obsidian-sync` home. Agents can access the vault but cannot directly
read that account's credentials. The client is packaged from Hermes's existing
locked nixpkgs, without a new flake input or runtime npm install. Fi and
Akkala both use the shared NixOS `services.obsidian-headless` module.

Log in manually as the sync account, select the existing remote vault and
complete its first sync before enabling continuous sync. Continuous `obsidian-4V2.service` startup is gated by
`/var/lib/obsidian-sync/4V2.ready`, created only after successful setup. Its
sandbox permits writes only to sync state and the vault. A setgid directory and
default ACLs preserve shared access for ordinary files created with umask 077.
Explicit restrictive creation modes or chmod can still break shared access.
The isolated `server-fi-vault-permissions` flake test checks these permissions
with fake credential fixtures. Run it on Linux before provisioning.

Trusted agent tools can share the `agent` account, with separate tool settings
and project workspaces. A user is a permission role, not one account per tool.
Those tools can generally access each other's files and credentials. Use separate
accounts where permissions differ, and restricted containers or VMs for
untrusted workloads. The T3 backend is a control server, not a permission sandbox.

Tmux survives an SSH disconnect but not a VM reboot. No automatic agent-task continuation,
snapshot schedule or backup policy is configured. Back up agent state,
workspaces and the vault independently before updates. Sync is not a backup.
Instance destruction is blocked, and image changes do not replace the existing
VM. Update the guest
through NixOS generations, not by recreating its disk.

## Remote state

Local state is suitable for bootstrap, but migrate it to a remote backend before
routine management. A TrueNAS S3 bucket is supported if it is:

- outside `spirit-spring/server-zant`
- versioned
- protected independently from Incus
- backed up or replicated outside the appliance

`backend-s3.tf.example` contains a secret-free template. Backend credentials
must come from environment variables. After creating `backend.tf`, migrate the
existing state with:

```bash
tofu init -migrate-state
```

An external S3-compatible backend provides better failure-domain separation
than storing both workloads and state on the same TrueNAS appliance.

## 4Ubuntu recovery and adoption

OpenTofu does not convert or restore the XCP-ng VHD. The recovery sequence is:

1. Record the original VHD's size, `qemu-img info`, and SHA-256 checksum.
2. Make the source read-only and never run a repair operation against it.
3. Convert to a separate raw or QCOW2 working image; `incus-migrate` does not
   directly support VHD.
4. Use `incus-migrate` to create a VM in the `truenas` pool with profiles
   `default` and `4ubuntu-vm`.
5. Determine whether the old VM used UEFI or legacy BIOS before first boot.
6. Boot with console access on the isolated NAT network and verify disks,
   filesystems, services, and networking.
7. Stop the VM and make a native Incus export in addition to preserving the VHD.
8. Add an `incus_instance` resource with `prevent_destroy=true` and import the
   verified VM into state.
9. Reject any OpenTofu plan that proposes replacing the imported VM.

The provider warns that importing an instance without an image identifier can
cause a replacement plan. The final VM resource and import command must
therefore be prepared from the restored instance's actual configuration rather
than added before recovery.

The current NAT network allows `4Ubuntu` to initiate connections to LAN hosts.
If LAN hosts must initiate connections to Docker services inside the VM, add
explicit network forwards or design a physical bridge after recovery.
