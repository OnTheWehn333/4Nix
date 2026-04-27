{
  pkgs,
  inputs,
  config,
  ...
}: let
  gpgSshKeygrips = import ../shared/gpg-ssh-keygrips.nix;
  gpgSigningKeys = import ../shared/gpg-signing-keys.nix;
in {
  imports = [
    inputs.sops-nix-darwin.homeManagerModules.sops
    ../../home-modules/node.nix
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/ranger.nix
    ../../home-modules/nushell.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/tmux.nix
    ../../home-modules/portal.nix
    ../../home-modules/nix.nix
    ../../home-modules/ghostty.nix
    ../../home-modules/opencode.nix
    ../../home-modules/zoxide.nix
    ../../home-modules/tmux-sessionizer.nix
    ../../home-modules/tunnel9.nix
    ../../home-modules/atac.nix
    ../../home-modules/scrcpy.nix
    ../../home-modules/android-tools.nix
    ../../home-modules/agenix.nix
    ../../home-modules/chafa.nix
    ../../home-modules/keysync.nix
    ../../home-modules/lazydocker.nix
    ../../home-modules/kafka.nix
    ../../home-modules/sops.nix
    ../../home-modules/clipboard.nix
    ../../home-modules/azure.nix
    ../../home-modules/kubernetes.nix
    ../../home-modules/terraform.nix
    ../../home-modules/ssh.nix
    ../../home-modules/obsidian.nix
    ../../home-modules/akkala-connect.nix
    ../../home-modules/pi.nix
  ];

  sops.defaultSopsFile = ../../secrets/pc-hylia/secrets.yaml;
  sops.gnupg.home = "${config.home.homeDirectory}/.gnupg";

  services.gpg-agent.sshKeys = [
    gpgSshKeygrips.pc-hylia
  ];

  programs.git.signing.key = gpgSigningKeys.pc-hylia;

  custom.oh-my-posh.hostColor = "#7aa2f7"; # Lake Hylia — serene blue waters

  programs.zsh = {
    enable = true;
    defaultKeymap = "viins";
  };
  programs.fzf.enable = true;
  programs.home-manager.enable = true;

  # Other machine-specific home configurations
  home.packages = with pkgs; [
    tree
    vim
    neofetch
  ];

  custom.pi = {
    enable = true;
    packages = [
      "npm:pi-mono-ask-user-question"
      "npm:pi-mono-auto-fix"
      "npm:pi-mono-btw"
      "npm:pi-mono-context-guard"
      "npm:pi-mono-simplify"
      "npm:pi-markdown-preview"
    ];
  };

  home.stateVersion = "25.11";

  # Obsidian: desktop app (Darwin default, syncMode = "gui")
  services.obsidian = {
    enable = true;
    vaults = ["4Vault" "4V2"];
  };
}
