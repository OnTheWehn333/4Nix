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
    extraGroups = ["wheel"];
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
    sshHostKeys.server-tenoko
  ];

  # Add system-wide packages
  environment.systemPackages = with pkgs; [
    vim
    git
    rsync
  ];

  home-manager.users.noahbalboa66 = import ./home.nix;

  # This value determines the NixOS release with which your system is to be compatible
  system.stateVersion = "25.11";
}
