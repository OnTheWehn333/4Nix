{
  config,
  lib,
  pkgs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;
in {
  networking = {
    hostName = "server-gohdan";
    useDHCP = lib.mkDefault true;
    nftables.enable = true;

    firewall = {
      enable = true;
      extraInputRules = ''
        ip saddr 10.100.0.1 tcp dport 22 accept
        ip saddr { 10.100.0.1, 10.100.0.122 } tcp dport 9000 accept
      '';
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Decrypt host-scoped SOPS secrets with this VM's existing Ed25519 SSH host
  # key. Only the corresponding public age recipient is stored in Git.
  sops = {
    defaultSopsFile = ../../secrets/server-gohdan/secrets.yaml;
    useSystemdActivation = true;

    age = {
      generateKey = false;
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };

    secrets = {
      "authentik-secret-key" = {};
      "authentik-postgresql-password" = {};
    };

    templates = {
      "authentik.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = ["authentik-compose.service"];
        content = ''
          AUTHENTIK_DISABLE_UPDATE_CHECK=true
          AUTHENTIK_ERROR_REPORTING__ENABLED=false
          AUTHENTIK_LOG_LEVEL=info
          AUTHENTIK_POSTGRESQL__HOST=postgresql
          AUTHENTIK_POSTGRESQL__NAME=authentik
          AUTHENTIK_POSTGRESQL__PASSWORD=${config.sops.placeholder."authentik-postgresql-password"}
          AUTHENTIK_POSTGRESQL__SSLMODE=disable
          AUTHENTIK_POSTGRESQL__USER=authentik
          AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik-secret-key"}
        '';
      };

      "authentik-postgresql.env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = ["authentik-compose.service"];
        content = ''
          POSTGRES_DB=authentik
          POSTGRES_PASSWORD=${config.sops.placeholder."authentik-postgresql-password"}
          POSTGRES_USER=authentik
        '';
      };
    };
  };

  services.authentik-compose = {
    enable = true;
    authentikEnvironmentFile = config.sops.templates."authentik.env".path;
    postgresEnvironmentFile = config.sops.templates."authentik-postgresql.env".path;
  };

  programs.zsh.enable = true;

  users.users = {
    # The generic Incus image enables passwordless root console login for
    # bootstrap. Lock it here so this identity VM is key-administered only.
    root.initialHashedPassword = lib.mkForce "!";

    noahbalboa66 = {
      isNormalUser = true;
      extraGroups = [
      "docker"
      "wheel"
    ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = builtins.filter (key: key != "") [
        sshHostKeys.pc-hylia
        sshHostKeys.pc-akkala
      ];
    };
  };

  services.getty.helpLine = lib.mkForce "";

  # Administrative access is SSH-key-only. This permits remote system recovery
  # before a separate non-GPG secret bootstrap mechanism is configured.
  security.sudo.wheelNeedsPassword = false;

  services = {
    openssh = {
      enable = true;
      settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    tailscale.enable = true;
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    tmux
    vim
  ];

  home-manager.users.noahbalboa66 = import ./home.nix;

  time.timeZone = "America/Chicago";

  system.stateVersion = "26.05";
}
