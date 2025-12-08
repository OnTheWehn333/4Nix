{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tak-server;
in {
  ###### ───────────────────────────────
  ## Options
  ###### ───────────────────────────────
  options.services.tak-server = {
    enable = lib.mkEnableOption "TAK Server tools and environment for manual setup";

    workDir = lib.mkOption {
      type = lib.types.path;
      default = "/opt/tak-server";
      description = "Working directory for TAK Server files";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports required for TAK Server";
    };
  };

  ###### ───────────────────────────────
  ## Implementation
  ###### ───────────────────────────────
  config = lib.mkIf cfg.enable {
    ##########################
    # Install required tools
    ##########################
    environment.systemPackages = with pkgs; [
      docker
      docker-compose
      git
      unzip
      nettools  # provides netstat
      curl
      wget
    ];

    ##########################
    # Enable Docker
    ##########################
    virtualisation.docker.enable = true;

    ##########################
    # Add user to docker group
    ##########################
    users.users.noahbalboa66.extraGroups = ["docker"];

    ##########################
    # Create working directory
    ##########################
    systemd.tmpfiles.rules = [
      "d ${cfg.workDir} 0755 noahbalboa66 users -"
    ];

    ##########################
    # Firewall configuration (optional)
    ##########################
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        5432  # PostgreSQL
        8089  # TAK Server API
        8443  # TAK Server Web UI (HTTPS)
        8444  # TAK Server client connections
        8446  # TAK Server federation
        9000  # TAK Server streaming
        9001  # TAK Server streaming
      ];
    };
  };
}
