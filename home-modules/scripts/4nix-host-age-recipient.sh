#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

required_commands=(awk ssh ssh-keygen ssh-to-age tr wc)
missing_commands=()

for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    missing_commands+=("$command_name")
  fi
done

if [ "${#missing_commands[@]}" -gt 0 ]; then
  if ! command -v nix >/dev/null 2>&1; then
    printf 'Missing required commands: %s\n' "${missing_commands[*]}" >&2
    echo "Nix is unavailable, so dependencies cannot be provided automatically." >&2
    exit 1
  fi

  if [ "${_4NIX_HOST_AGE_NIX_SHELL:-0}" = "1" ]; then
    printf 'Dependencies remain unavailable inside nix shell: %s\n' "${missing_commands[*]}" >&2
    exit 1
  fi

  export _4NIX_HOST_AGE_NIX_SHELL=1
  exec nix shell \
    nixpkgs#coreutils \
    nixpkgs#gawk \
    nixpkgs#openssh \
    nixpkgs#ssh-to-age \
    --command "$0" "$@"
fi

usage() {
  cat <<'USAGE'
Usage: 4nix-host-age-recipient [--raw] <ssh-target>

Retrieve a host's public Ed25519 SSH host key over SSH and convert it to the
age recipient used by sops-nix.

Arguments:
  <ssh-target>  Any target accepted by ssh, including a configured host alias
                or user@hostname.

Options:
  --raw         Print only the age recipient for command substitution.
  -h, --help    Show this help.

Examples:
  4nix-host-age-recipient server-gohdan
  4nix-host-age-recipient noahbalboa66@192.168.1.20
  recipient="$(4nix-host-age-recipient --raw server-gohdan)"

The command reads only /etc/ssh/ssh_host_ed25519_key.pub. It never reads the
host's private SSH key and does not edit .sops.yaml.
USAGE
}

raw=false

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --raw)
    raw=true
    shift
    ;;
esac

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

target="$1"
public_key="$(${SSH:-ssh} -o BatchMode=yes -- "$target" \
  'cat /etc/ssh/ssh_host_ed25519_key.pub')"

line_count="$(printf '%s\n' "$public_key" | wc -l | tr -d '[:space:]')"
if [ "$line_count" != "1" ]; then
  echo "Expected exactly one SSH public key from $target; received $line_count lines." >&2
  exit 1
fi

case "$public_key" in
  ssh-ed25519\ *) ;;
  *)
    echo "Expected an Ed25519 SSH host public key from $target." >&2
    exit 1
    ;;
esac

fingerprint="$(printf '%s\n' "$public_key" | ssh-keygen -lf - | awk '{print $2}')"
recipient="$(printf '%s\n' "$public_key" | ssh-to-age)"

if [ "$raw" = true ]; then
  printf '%s\n' "$recipient"
else
  printf 'SSH target:  %s\n' "$target"
  printf 'Fingerprint: %s\n' "$fingerprint"
  printf 'Age recipient: %s\n' "$recipient"
fi
