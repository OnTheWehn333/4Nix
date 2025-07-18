{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/ranger.nix
    ../../home-modules/nushell.nix
    ../../home-modules/claude-code.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/tmux.nix
    ../../home-modules/ghostty.nix
    ../../home-modules/tmux-sessionizer.nix
  ];

  programs.zsh = {
    enable = true;
  };

  programs.fzf.enable = true;

  # Other machine-specific home configurations
  home.packages = with pkgs; [
    tree
    vim
    neofetch
    # Other packages specific to this machine
  ];

  home.stateVersion = "25.05";
}
