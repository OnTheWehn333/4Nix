{ config, lib, pkgs, ... }:

{
  imports = [
    # Import hardware configuration
    ./hardware-configuration.nix
  ];

  networking.hostName = "server-tenoko";

  # Boot configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  # Define a user account
  users.users.noahbalboa66 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    packages = [ ];
    shell = pkgs.nushell;
  };

  # Set your time zone
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  # Add system-wide packages
  environment.systemPackages = with pkgs; [
    vim
    git
    tmux
    # Any other system packages you want to install
  ];
  home-manager.users.noahbalboa66 = import ./home.nix;

  # This value determines the NixOS release with which your system is to be compatible
  system.stateVersion = "25.05";
}
