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

## Initial local state

The initial backend is OpenTofu's local backend. State is ignored by Git. The
provider connects to the local Incus Unix socket, so run OpenTofu on
`server-zant` as a user in `incus-admin`.

Initialize without changing Incus:

```bash
cd ~/projects/4Nix/infrastructure/server-zant
tofu init
tofu fmt -check
tofu validate
```

During the one-time ownership transition on the current server, adopt the
network and profiles that already exist from the former Nix Incus preseed:

```bash
tofu import incus_network.incusbr0 incusbr0
tofu import incus_profile.default default
tofu import incus_profile.four_ubuntu_vm 4ubuntu-vm
tofu plan
```

Review the entire plan. Do not apply if it proposes replacement or deletion.
The Nix preseed has been removed after this import handoff; removing it does not
delete existing Incus objects.

The `incus_server.server_zant` resource requires no import. Its first plan is
shown as a create operation, but the provider does not create or replace the
Incus daemon. It adopts the existing server and manages only the explicitly
configured `core.https_address` setting.

On a genuinely fresh host with no Incus API objects, skip the import commands;
OpenTofu will create the network and profiles from this configuration.

## TrueNAS storage gate

The TrueNAS pool is disabled by default. First confirm API access and that the
intended child dataset does not exist:

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
Initiator-group comment: server-zant
Local initiator IQN:     iqn.2026-06.dev.4nix:server-zant
Root size:               256GiB
```

Confirm that `spirit-spring/server-zant` does not exist or is empty. Keep
`truenas.force_reuse=false`; it prevents accidental adoption of an existing
nonempty dataset.

Before running `share iscsi setup --test`, create or verify a dedicated TrueNAS
iSCSI initiator group whose comment is exactly `server-zant` and whose allowed
initiator is exactly `iqn.2026-06.dev.4nix:server-zant`. Portal ID `1` is the
existing `0.0.0.0:3260` listener and can serve both old and new targets. The
setup command can mutate TrueNAS if the named portal or initiator group is
absent.

After those objects are verified, test the exact selections:

```bash
sudo truenas_incus_ctl \
  --config-file /run/secrets/rendered/truenas-incus-ctl-config \
  --config truenas \
  share iscsi setup --test \
  --portal 1 \
  --initiator server-zant
```

When the API, iSCSI test, and dataset check all pass, create an untracked
`terraform.tfvars` containing:

```hcl
enable_truenas_pool = true
```

Then review `tofu plan` before applying. Enabling the pool also adds the root
disk device to the `default` profile.

OpenTofu and Incus state contain only the config profile name `truenas`, not
the API key or rendered file path. Nix places a wrapper in the Incus service
PATH that injects the root-only rendered `--config-file` when the driver invokes
`truenas_incus_ctl`.

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
