{
  lib,
  pkgs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "server-zant";
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;

  # HP ProLiant DL380p Gen8 currently boots XCP-ng from this local logical volume.
  # Only use this as an install target after intentionally retiring/wiping XCP-ng.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = lib.mkDefault "/dev/disk/by-id/wwn-0x600508b1001c1c12bd1ca0c65bb3541c";
  boot.zfs.forceImportRoot = false;

  nix = {settings = {experimental-features = ["nix-command" "flakes"];};};

  programs.zsh.enable = true;

  users.users.noahbalboa66 = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "incus-admin"];
    packages = [];
    shell = pkgs.zsh;
  };

  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.tailscale.enable = true;

  virtualisation.incus.enable = true;

  services.openiscsi = {
    enable = true;
    name = "iqn.2026-06.dev.4nix:server-zant";
  };

  users.users.noahbalboa66.openssh.authorizedKeys.keys = builtins.filter (key: key != "") [
    sshHostKeys.pc-hylia
    sshHostKeys.pc-akkala
  ];

  environment.systemPackages = with pkgs; [
    curl
    dmidecode
    git
    jq
    lvm2
    tmux
    truenas-incus-ctl
    vim
  ];

  home-manager.users.noahbalboa66 = import ./home.nix;

  system.stateVersion = "26.05";
}
