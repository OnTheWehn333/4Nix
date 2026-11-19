{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/node.nix
    ../../home-modules/pnpm.nix
    ../../home-modules/java.nix
    ../../home-modules/nix.nix
    ../../home-modules/nh.nix
    ../../home-modules/zoxide.nix
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;
  programs.fzf.enable = true;

  home.packages = with pkgs; [
    go
    gcc
    gnumake
    cmake
    pkg-config
    fd
    tree
    rsync
    sqlite
  ];

  home.stateVersion = "26.05";
}
