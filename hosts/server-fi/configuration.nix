{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;
  operatorKeys = builtins.filter (key: key != "") [
    sshHostKeys.pc-hylia
    sshHostKeys.pc-akkala
  ];
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  trialPkgs = import inputs.nixpkgs-t3 {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = false;
  };
  t3Package = trialPkgs.t3code.override {
    enableCodex = false;
    enableGitHub = false;
  };
  piPackage = trialPkgs.pi-coding-agent;
  hermesSession = pkgs.writeShellApplication {
    name = "hermes-session";
    runtimeInputs = [pkgs.tmux hermesPackage];
    text = ''
      umask 077
      exec tmux new-session -A -s hermes -c "$HOME/workspace" hermes
    '';
  };
in {
  imports = [./obsidian.nix ../../modules/t3-code.nix];

  networking = {
    hostName = "server-fi";
    useDHCP = lib.mkDefault true;
    nftables.enable = true;
    firewall = {
      enable = true;
      # ProxyJump connections originate from Zant's bridge address.
      extraInputRules = ''
        ip saddr 10.100.0.1 tcp dport 22 accept
      '';
    };
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  users.users = {
    # The generic Incus image permits root console login without a password.
    root.initialHashedPassword = lib.mkForce "!";

    noahbalboa66 = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = operatorKeys;
    };

    agent = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      description = "Shared agent account";
      home = "/home/agent";
      homeMode = "0700";
      createHome = true;
      linger = true;
      openssh.authorizedKeys.keys = operatorKeys;
      packages = [hermesPackage hermesSession t3Package piPackage];
    };
  };

  services.t3-code = {
    enable = true;
    package = t3Package;
    user = "agent";
    workingDirectory = "${config.users.users.agent.home}/workspace";
    path = [hermesPackage piPackage];
  };

  services.getty.helpLine = lib.mkForce "";
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = ["noahbalboa66" "agent"];
    };
    extraConfig = ''
      Match User agent
        AllowAgentForwarding no
        AllowTcpForwarding no
        X11Forwarding no
      Match all
    '';
  };

  # No provider credentials enter Nix evaluation or the VM image. Run
  # `hermes setup` as agent after provisioning; its state is ~/.hermes.
  programs.bash.interactiveShellInit = ''
    if [[ "$USER" == agent ]]; then
      umask 077
    fi
  '';

  systemd.tmpfiles.rules = [
    "d ${config.users.users.agent.home}/workspace 0700 agent users -"
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    nh
    ripgrep
    tmux
    vim
  ];

  home-manager.users = {
    noahbalboa66 = import ./home-noahbalboa66.nix;
    agent = import ./home-agent.nix;
  };

  # The shared dev bundle prepares Rust and Neovim through user activations.
  systemd.services =
    lib.genAttrs ["home-manager-noahbalboa66" "home-manager-agent"] (_: {
      wants = ["network-online.target"];
      after = ["network-online.target"];
    })
    // {
      t3-code.after = ["home-manager-agent.service"];
    };

  time.timeZone = "America/Chicago";
  system.stateVersion = "26.05";
}
