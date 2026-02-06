{pkgs, ...}: {
  imports = [
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/ranger.nix
    ../../home-modules/nushell.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/tmux.nix
    ../../home-modules/portal.nix
    ../../home-modules/ghostty.nix
    ../../home-modules/opencode.nix
    ../../home-modules/zoxide.nix
    ../../home-modules/tmux-sessionizer.nix
    ../../home-modules/tunnel9.nix
    ../../home-modules/atac.nix
  ];

  programs.zsh = {
    enable = true;
  };

  programs.fzf.enable = true;

  # opencode: set useLatest = true to build from GitHub source
  programs.opencode = {
    enable = true;
    useLatest = true;
  };

  programs.home-manager.enable = true;

  # Other machine-specific home configurations
  home.packages = with pkgs; [
    tree
    vim
    neofetch
    # Other packages specific to this machine
  ];

  home.stateVersion = "25.05";
}
