{pkgs, ...}: let
  gpgSshKeygrips = import ../shared/gpg-ssh-keygrips.nix;
in {
  imports = [
    ../../home-modules/keysync.nix
    ../../home-modules/nh.nix
    ../../home-modules/nix.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/ranger.nix
    ../../home-modules/tmux.nix
    ../../home-modules/zoxide.nix
  ];

  custom.oh-my-posh.hostColor = "#bb9af7"; # Zant — Twilight Realm purple

  programs.zsh = {
    enable = true;
    defaultKeymap = "viins";
  };
  programs.fzf.enable = true;
  programs.home-manager.enable = true;

  services.gpg-agent.sshKeys = [
    gpgSshKeygrips.server-zant
  ];

  home.packages = with pkgs; [
    fastfetch
    tree
    vim
  ];

  home.stateVersion = "26.05";
}
