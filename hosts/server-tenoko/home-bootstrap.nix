{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../home-modules/keysync.nix
  ];

  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
