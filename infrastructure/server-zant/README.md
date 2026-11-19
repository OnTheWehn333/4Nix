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

## VM image paths and overrides

Gohdan previously used the generic `result/` directory. Before the next plan,
use the root playbook's manual preparation steps to copy those artifacts into
`result-server-gohdan/` and compare checksums, but only if you know they are
Gohdan's image. The copy preserves `result/` and does not overwrite existing
files. Matching checksums establish copy integrity, not image provenance.
For future Gohdan builds, use the `server-gohdan-incus-image` output with the
same Hylia-evaluation and Zant-build workflow as Fi, and transfer the artifacts
to `result-server-gohdan/`, not `result/`.

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
