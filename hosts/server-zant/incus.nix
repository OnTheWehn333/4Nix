{
  config,
  lib,
  pkgs,
  ...
}: let
  bridgeName = "incusbr0";
  trueNasConfigFile = "/run/secrets/rendered/truenas-incus-ctl-config";
  trueNasIncusCtl = pkgs.writeShellApplication {
    name = "truenas_incus_ctl";
    text = ''
      exec ${lib.getExe pkgs.truenas-incus-ctl} \
        --config-file ${lib.escapeShellArg trueNasConfigFile} "$@"
    '';
  };
in {
  networking.nftables = {
    enable = true;
    flushRuleset = false;
  };

  networking.firewall = {
    trustedInterfaces = [bridgeName];
    allowedTCPPorts = [8443];
  };

  virtualisation.incus = {
    enable = true;
    ui.enable = true;
  };

  services.openiscsi = {
    enable = true;
    name = "iqn.2026-06.dev.4nix:server-zant";
  };

  # Incus 7.0 passes truenas.config as the helper's named --config profile but
  # has no pool option for --config-file. This wrapper injects the root-only
  # rendered file without placing its API key in Incus or OpenTofu state.
  systemd.services.incus.path = [trueNasIncusCtl];

  environment.systemPackages = with pkgs; [
    incus-lts
    jq
    lvm2
    opentofu
    qemu-utils
    rsync
    truenas-incus-ctl
  ];
}
