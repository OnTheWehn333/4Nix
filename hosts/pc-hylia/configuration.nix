{
  config,
  pkgs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;
in {
  # Required
  system.stateVersion = 4;
  ids.gids.nixbld = 350;

  # Host basics
  networking.hostName = "pc-hylia";

  nix = {settings = {experimental-features = ["nix-command" "flakes"];};};

  environment.systemPackages = with pkgs; [
    git
  ];

  # Users and packages
  users.users.noahbalboa66 = {
    home = "/Users/noahbalboa66";
  };

  services.openssh.enable = true;
  services.tailscale.enable = true;

  users.users.noahbalboa66.openssh.authorizedKeys.keys = builtins.filter (key: key != "") [
    sshHostKeys.server-tenoko
    sshHostKeys.pc-akkala
  ];

  # Home-Manager entry point
  home-manager.users.noahbalboa66 = import ./home.nix;
}
