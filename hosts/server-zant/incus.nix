{
  config,
  lib,
  pkgs,
  ...
}: let
  bridgeName = "incusbr0";
  lanInterface = "eno1";
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
    allowedUDPPorts = [8211];
    interfaces = {
      ${lanInterface}.allowedTCPPorts = [8443];
      tailscale0.allowedTCPPorts = [8443];
    };
  };

  virtualisation = {
    docker.enable = true;
    incus = {
      enable = true;
      ui.enable = true;
    };
  };

  services.openiscsi = {
    enable = true;
    name = "iqn.2026-06.dev.4nix:server-zant";
  };

  # Start systemd's iSCSI socket before Incus tooling can auto-spawn an
  # unmanaged iscsid process that claims the same abstract IPC socket.
  systemd.services.incus = {
    requires = ["iscsid.socket"];
    after = ["iscsid.socket"];

    # Incus 7.0 passes truenas.config as the helper's named --config profile but
    # has no pool option for --config-file. This wrapper injects the root-only
    # rendered file without placing its API key in Incus or OpenTofu state.
    path = [
      trueNasIncusCtl
      config.services.openiscsi.package
    ];
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    incus-lts
    jq
    lvm2
    opentofu
    qemu-utils
    rsync
    truenas-incus-ctl
  ];
}
