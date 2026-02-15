{
  pkgs,
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/ranger.nix
    ../../home-modules/nushell.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/tmux.nix
    ../../home-modules/portal.nix
    ../../home-modules/opencode.nix
    ../../home-modules/zoxide.nix
    ../../home-modules/tmux-sessionizer.nix
    ../../home-modules/keysync.nix
    ../../home-modules/lazydocker.nix
  ];

  sops.defaultSopsFile = ../../secrets/server-tenoko/secrets.yaml;
  sops.gnupg.home = "${config.home.homeDirectory}/.gnupg";

  programs.home-manager.enable = true;

  # opencode: set useLatest = true to build from GitHub source
  programs.opencode = {
    enable = true;
    # useLatest = true;  # Uncomment to use bleeding-edge from GitHub
  };

  # Other machine-specific home configurations
  home.packages = with pkgs; [
    tree
    vim
    ranger
    neofetch
    # Other packages specific to this machine
  ];

  home.stateVersion = "25.11";
}
