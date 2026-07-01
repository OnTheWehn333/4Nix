{
  inputs,
  lib,
  pkgs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;

  trustedSshKeys = builtins.filter (key: key != "") [
    sshHostKeys.pc-hylia
    sshHostKeys.pc-akkala
  ];

  keysync = pkgs.buildGoModule {
    pname = "keysync";
    version = "0.1.0";
    src = ../../tools/keysync;
    vendorHash = "sha256-komX1AmHt2NoF1x6xsNa2RFkfVzOXfYEMPhT0zwMxjw=";
    doCheck = false;

    meta = with lib; {
      mainProgram = "keysync";
      description = "GPG subkey sync to 1Password per host";
      homepage = "https://github.com/OnTheWehn333/keysync";
      license = licenses.mit;
    };
  };

  preseedKeys = pkgs.writeShellApplication {
    name = "4nix-preseed-keys";
    runtimeInputs = [
      keysync
      pkgs._1password-cli
      pkgs.coreutils
      pkgs.gnupg
    ];
    text = builtins.readFile ./4nix-preseed-keys.sh;
  };

in {
  networking.hostName = "4nix-installer";
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "nixos"];
    };
  };

  services.openssh.enable = true;
  services.tailscale.enable = true;

  # Ephemeral Incus daemon for bare-metal smoke tests from the live ISO.
  virtualisation.incus.enable = true;

  services.openiscsi = {
    enable = true;
    name = "iqn.2026-06.dev.4nix:installer";
  };

  boot.zfs.forceImportRoot = false;

  users.users.root.openssh.authorizedKeys.keys = trustedSshKeys;
  users.users.nixos = {
    extraGroups = ["wheel" "networkmanager" "incus-admin"];
    openssh.authorizedKeys.keys = trustedSshKeys;
  };

  security.sudo.wheelNeedsPassword = false;

  systemd.tmpfiles.rules = [
    "L+ /opt/4Nix - - - - ${../../.}"
  ];

  environment.systemPackages = with pkgs; [
    keysync
    preseedKeys

    _1password-cli
    age
    cifs-utils
    curl
    dmidecode
    inputs.disko.packages.${pkgs.system}.disko
    git
    gnupg
    gptfdisk
    hdparm
    incus
    jq
    lvm2
    nfs-utils
    nh
    nixos-install-tools
    nvme-cli
    parted
    pciutils
    rsync
    sops
    smartmontools
    tmux
    truenas-incus-ctl
    usbutils
    vim
    wget
  ];

  system.stateVersion = "26.05";
}
