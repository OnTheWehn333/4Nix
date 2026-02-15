{
  config,
  lib,
  pkgs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;
in {
  imports = [
    # Import hardware configuration
    ./hardware-configuration.nix
  ];

  networking.hostName = "server-tenoko";

  # Boot configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  nix = {settings = {experimental-features = ["nix-command" "flakes"];};};

  # Define a user account
  users.users.noahbalboa66 = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    packages = [];
    shell = pkgs.nushell;
  };

  programs.bash.interactiveShellInit = ''
    if ! [ "$TERM" = "dumb" ] && [ -z "$BASH_EXECUTION_STRING" ]; then
      exec nu
    fi
  '';

  # Set your time zone
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;

  users.users.noahbalboa66.openssh.authorizedKeys.keys = builtins.filter (key: key != "") [
    sshHostKeys.pc-hylia
  ];

  # Add system-wide packages
  environment.systemPackages = with pkgs; [
    vim
    git
    tmux
    # Any other system packages you want to install
  ];
  home-manager.users.noahbalboa66 = import ./home.nix;

  # This value determines the NixOS release with which your system is to be compatible
  system.stateVersion = "25.11";
}
