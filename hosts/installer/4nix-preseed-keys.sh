set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: 4nix-preseed-keys <host> [target-root=/mnt] [repo=/opt/4Nix]

Restores keys for <host> from 1Password into the mounted target root's
future user GPG home. It also installs the host encryption subkey into a
root-owned GPG home for unattended system-level sops decryption.

Arguments:
  <host>              Host name from keysync.yaml.
  [target-root]       Mounted target root filesystem. Defaults to /mnt.
  [repo]              4Nix repo path containing keysync.yaml. Defaults to /opt/4Nix.

Example install flow:
  host=server-zant
  git clone --branch zant https://github.com/OnTheWehn333/4Nix.git /tmp/4Nix
  cd /tmp/4Nix
  eval $(op signin)
  4nix-preseed-keys "$host" /mnt .
  nix build --out-link /tmp/host-system ".#nixosConfigurations.\"$host\".config.system.build.toplevel"
  nixos-install --system "$(readlink -f /tmp/host-system)"

Notes:
  - This writes GPG key material into the target root, not the live ISO.
  - The user keyring receives all host keys configured in keysync.yaml.
  - The root sops keyring receives only the configured host encryption subkey.
  - Do not embed private keys or decrypted secrets in the ISO.
  - For temporary live-session key testing, run keysync directly with GNUPGHOME.
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  usage >&2
  exit 2
fi

host="$1"
target="${2:-/mnt}"
repo="${3:-/opt/4Nix}"
user="noahbalboa66"
gpg_home="$target/home/$user/.gnupg"
sops_gpg_home="$target/var/lib/sops-nix/gnupg"

if [ ! -d "$target" ]; then
  echo "Target root does not exist: $target" >&2
  exit 1
fi

if [ ! -f "$repo/keysync.yaml" ]; then
  echo "keysync.yaml not found in repo path: $repo" >&2
  exit 1
fi

if ! op whoami >/dev/null 2>&1; then
  cat >&2 <<'SIGNIN'
1Password CLI is not signed in.
Sign in first, then rerun this command:
  eval $(op signin)
SIGNIN
  exit 1
fi

install -d -m 0755 "$target/home"
install -d -m 0755 "$target/home/$user"
install -d -m 0700 "$gpg_home"

GNUPGHOME="$gpg_home" keysync --config "$repo/keysync.yaml" restore --host "$host"

encryption_fingerprint="$(
  yq -r ".keys.\"$host\".subkeys.encrypt.fingerprint // \"\"" "$repo/keysync.yaml"
)"

if [ -z "$encryption_fingerprint" ]; then
  echo "No encryption subkey configured for host: $host" >&2
  exit 1
fi

install -d -m 0700 "$sops_gpg_home"

GNUPGHOME="$gpg_home" gpg --batch --export "$encryption_fingerprint" \
  | GNUPGHOME="$sops_gpg_home" gpg --batch --import

GNUPGHOME="$gpg_home" gpg --batch --export-secret-subkeys "$encryption_fingerprint!" \
  | GNUPGHOME="$sops_gpg_home" gpg --batch --import

GNUPGHOME="$sops_gpg_home" gpgconf --kill all || true

# NixOS' default users group is normally gid 100. If the target user does
# not exist yet, numeric chown is still fine for the future installed host.
chown -R 1000:100 "$target/home/$user" || true
chmod 700 "$gpg_home"
chown -R 0:0 "$sops_gpg_home"
chmod -R go-rwx "$sops_gpg_home"

echo "Restored user keys for $host into $gpg_home"
echo "Installed $host encryption subkey into $sops_gpg_home"
echo "Next: build the host closure and run nixos-install --system <closure>"
