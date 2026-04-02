{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;
in {
  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  # WSL configuration
  wsl.enable = true;
  wsl.defaultUser = "noahbalboa66";

  networking.hostName = "pc-akkala";

  nix = {settings = {experimental-features = ["nix-command" "flakes"];};};

  # Define a user account
  users.users.noahbalboa66 = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker"];
    linger = true;
    packages = [];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  # Set your time zone
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.tailscale.enable = true;
  systemd.services.tailscaled.after = ["network-online.target"];
  systemd.services.tailscaled.wants = ["network-online.target"];
  systemd.services.tailscaled.serviceConfig.ExecStartPre = [
    "-${pkgs.iproute2}/bin/ip link delete tailscale0"
  ];

  users.users.noahbalboa66.openssh.authorizedKeys.keys = builtins.filter (key: key != "") [
    sshHostKeys.pc-hylia
    sshHostKeys.server-tenoko
  ];

  # Enable nix-ld for dynamic binary compatibility (LSP servers, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
  ];

  # Add system-wide packages
  environment.systemPackages = with pkgs; [
    vim
    git
    nodejs
    yarn
    rsync
  ];

  home-manager.users.noahbalboa66 = import ./home.nix;

  users.groups.docker = {};
  wsl.docker-desktop.enable = true;

  # This value determines the NixOS release with which your system is to be compatible
  system.stateVersion = "25.11";
}
