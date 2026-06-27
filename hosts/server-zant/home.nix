{pkgs, ...}: {
  imports = [
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/keysync.nix
    ../../home-modules/nh.nix
    ../../home-modules/nix.nix
    ../../home-modules/ranger.nix
    ../../home-modules/tmux.nix
    ../../home-modules/zoxide.nix
  ];

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    fastfetch
    tree
    vim
  ];

  home.stateVersion = "26.05";
}
