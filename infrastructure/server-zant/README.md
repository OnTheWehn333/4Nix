# server-zant Incus infrastructure

OpenTofu owns Incus API resources on `server-zant`. Nix continues to own the
host OS, Incus daemon and packages, firewall prerequisites, Open-iSCSI,
`truenas_incus_ctl`, and the rendered SOPS configuration.

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

Before any apply, adopt the network and profiles that already exist from the
Nix Incus preseed:

```bash
tofu import incus_network.incusbr0 incusbr0
tofu import incus_profile.default default
tofu import incus_profile.four_ubuntu_vm 4ubuntu-vm
tofu plan
```

Review the entire plan. Do not apply if it proposes replacement or deletion.
After these imports produce an understood plan, remove network/profile API
object ownership from the Nix preseed in a separate change. Removing preseed
entries does not delete the existing Incus objects.

## TrueNAS storage gate

The TrueNAS pool is disabled by default. Before enabling it, both of these must
succeed:

```bash
sudo truenas_incus_ctl \
  --config-file /run/secrets/rendered/truenas-incus-ctl-config \
  --config truenas \
  dataset ls

sudo truenas_incus_ctl \
  --config-file /run/secrets/rendered/truenas-incus-ctl-config \
  --config truenas \
  share iscsi setup --test
```

The intended Incus pool is:

```text
Incus pool:     truenas
TrueNAS source: spirit-spring/server-zant
Root size:      256GiB
```

Confirm that `spirit-spring/server-zant` does not exist or is empty. Keep
`truenas.force_reuse=false`; it prevents accidental adoption of an existing
nonempty dataset.

When the API, iSCSI test, and dataset check all pass, create an untracked
`terraform.tfvars` containing:

```hcl
enable_truenas_pool = true
```

Then review `tofu plan` before applying. Enabling the pool also adds the root
disk device to the `default` profile.

The state contains the path to the rendered TrueNAS configuration, not the API
key itself.

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
