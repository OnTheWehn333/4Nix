{ pkgs, ... }:

{
  imports = [
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/ranger.nix
    ../../home-modules/nushell.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/tmux.nix
    ../../home-modules/tmux-sessionizer.nix
  ];

  # Other machine-specific home configurations
  home.packages = with pkgs; [
    tree
    vim
    ranger
    neofetch
    # Other packages specific to this machine
  ];

  home.stateVersion = "24.11";
}
