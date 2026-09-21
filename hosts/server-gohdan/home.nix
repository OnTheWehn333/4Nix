{pkgs, ...}: {
  imports = [
    ../../home-modules/nh.nix
    ../../home-modules/nix.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/ranger.nix
    ../../home-modules/tmux.nix
    ../../home-modules/zoxide.nix
  ];

  custom.oh-my-posh.hostColor = "#a9a9a9"; # Gohdan — ancient stone gray

  programs.zsh = {
    enable = true;
    defaultKeymap = "viins";
  };
  programs.fzf.enable = true;
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    fastfetch
    tree
    vim
  ];

  home.stateVersion = "26.05";
}
