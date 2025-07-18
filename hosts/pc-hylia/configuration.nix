{
  config,
  pkgs,
  ...
}: {
  # Required
  system.stateVersion = 4;
  ids.gids.nixbld = 350;

  # Host basics
  networking.hostName = "pc-hylia";

  environment.systemPackages = with pkgs; [
    git
    nodejs
    yarn
  ];

  # Users and packages
  users.users.noahbalboa66 = {
    home = "/Users/noahbalboa66";
  };

  # Home-Manager entry point
  home-manager.users.noahbalboa66 = import ./home.nix;
}
