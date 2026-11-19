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
    inputs.sops-nix.homeManagerModules.sops
    ../../home-modules/node.nix
    ../../home-modules/java.nix
    ../../home-modules/bundles/dev-tools.nix
    ../../home-modules/ranger.nix
    ../../home-modules/nushell.nix
    ../../home-modules/oh-my-posh.nix
    ../../home-modules/tmux.nix
    ../../home-modules/portal.nix
    ../../home-modules/nix.nix
    ../../home-modules/nh.nix
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
    ../../home-modules/obsidian.nix
    ../../home-modules/pi.nix
    ../../home-modules/agent-runner.nix
    ../../home-modules/azure.nix
    ../../home-modules/terraform.nix
    ../../home-modules/kubernetes.nix
    ../../home-modules/ssh.nix
  ];

  # Headless vault inventory, sync and home links are managed by the NixOS
  # services.obsidian-headless module configured in configuration.nix.

  sops.defaultSopsFile = ../../secrets/pc-akkala/secrets.yaml;
  sops.gnupg.home = "${config.home.homeDirectory}/.gnupg";

  services.gpg-agent.sshKeys = [
    gpgSshKeygrips.pc-akkala
  ];

  programs.git.signing.key = gpgSigningKeys.pc-akkala;

  custom.oh-my-posh.hostColor = "#e0af68"; # Akkala — autumn leaves, warm amber

  programs.zsh = {
    enable = true;
    defaultKeymap = "viins";
  };
  programs.fzf.enable = true;
  programs.home-manager.enable = true;
  systemd.user.startServices = false;

  # Other machine-specific home configurations
  home.packages = with pkgs; [
    tree
    vim
    ranger
    fastfetch
    rsync
  ];

  custom.agent-runner.enable = true;

  custom.pi = {
    enable = true;
    packages = [
      "npm:pi-mono-ask-user-question"
      "npm:pi-mono-auto-fix"
      "npm:pi-mono-btw"
      "npm:pi-mono-context-guard"
      "npm:pi-mono-simplify"
    ];
    settings = {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6.1-sol";
      defaultThinkingLevel = "high";
    };
  };

  home.stateVersion = "26.05";
}
