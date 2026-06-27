set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: 4nix-preseed-keys <host> [target-root=/mnt] [repo=/opt/4Nix]

Restores keys for <host> from 1Password into the mounted target root's
future GPG home, so nixos-install can install the full host profile directly.

Arguments:
  <host>              Host name from keysync.yaml.
  [target-root]       Mounted target root filesystem. Defaults to /mnt.
  [repo]              4Nix repo path containing keysync.yaml. Defaults to /opt/4Nix.

Example install flow:
  cd /opt/4Nix
  eval $(op signin)
  4nix-preseed-keys <host> /mnt .
  nixos-install --flake .#<host>

Notes:
  - This writes GPG key material into the target root, not the live ISO.
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

# NixOS' default users group is normally gid 100. If the target user does
# not exist yet, numeric chown is still fine for the future installed host.
chown -R 1000:100 "$target/home/$user" || true
chmod 700 "$gpg_home"

echo "Restored keys for $host into $gpg_home"
echo "Next: nixos-install --flake $repo#$host"
