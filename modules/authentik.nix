{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.authentik-compose;

  composeFile = pkgs.writeText "authentik-compose.yaml" (
    builtins.readFile cfg.composeFile
  );

  composeEnvironmentFile = pkgs.writeText "authentik-compose.env" ''
    AUTHENTIK_ENV_FILE=${cfg.authentikEnvironmentFile}
    AUTHENTIK_HTTP_PORT=${toString cfg.httpPort}
    AUTHENTIK_LISTEN_ADDRESS=${cfg.listenAddress}
    AUTHENTIK_POSTGRES_ENV_FILE=${cfg.postgresEnvironmentFile}
    AUTHENTIK_STATE_DIRECTORY=${cfg.stateDirectory}
  '';

  compose = "${lib.getExe pkgs.docker-compose} --project-name authentik --env-file ${composeEnvironmentFile} --file ${composeFile}";
in {
  options.services.authentik-compose = {
    enable = lib.mkEnableOption "the Authentik identity stack";

    composeFile = lib.mkOption {
      type = lib.types.path;
      default = ../stacks/authentik/compose.yaml;
      description = "Secret-free Docker Compose definition for Authentik.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.100.0.10";
      description = "Private address on which Authentik HTTP is published.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Private Authentik HTTP port.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/authentik";
      description = "Persistent Authentik and PostgreSQL state directory.";
    };

    backupDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/authentik";
      description = "Root-only local PostgreSQL dump directory.";
    };

    authentikEnvironmentFile = lib.mkOption {
      type = lib.types.str;
      description = "Root-only runtime environment file for Authentik.";
    };

    postgresEnvironmentFile = lib.mkOption {
      type = lib.types.str;
      description = "Root-only runtime environment file for PostgreSQL.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;
    environment.systemPackages = [pkgs.docker-compose];

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDirectory} 0750 root root -"
      "d ${cfg.stateDirectory}/database 0700 root root -"
      "d ${cfg.stateDirectory}/data 0750 root root -"
      "d ${cfg.stateDirectory}/certs 0750 root root -"
      "d ${cfg.backupDirectory} 0700 root root -"
    ];

    systemd.services.authentik-compose = {
      description = "Authentik Docker Compose stack";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      requires = [
        "docker.service"
        "sops-install-secrets.service"
      ];
      after = [
        "docker.service"
        "network-online.target"
        "sops-install-secrets.service"
      ];
      restartTriggers = [
        composeFile
        composeEnvironmentFile
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "15min";
        TimeoutStopSec = "2min";
      };

      script = "${compose} up --detach --remove-orphans";
      preStop = "${compose} down";
    };

    systemd.services.authentik-backup = {
      description = "Back up the Authentik PostgreSQL database";
      requires = ["authentik-compose.service"];
      after = ["authentik-compose.service"];

      serviceConfig = {
        Type = "oneshot";
        UMask = "0077";
      };

      script = ''
        timestamp="$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)"
        temporary="${cfg.backupDirectory}/.authentik-$timestamp.dump.tmp"
        destination="${cfg.backupDirectory}/authentik-$timestamp.dump"

        ${compose} exec --no-TTY postgresql \
          pg_dump --format=custom --username=authentik --dbname=authentik \
          > "$temporary"
        ${pkgs.coreutils}/bin/mv "$temporary" "$destination"
        ${pkgs.findutils}/bin/find ${lib.escapeShellArg cfg.backupDirectory} \
          -type f -name 'authentik-*.dump' -mtime +14 -delete
      '';
    };

    systemd.timers.authentik-backup = {
      description = "Daily Authentik PostgreSQL backup";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
