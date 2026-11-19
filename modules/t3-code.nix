{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.t3-code;
  inherit (lib) mkIf mkOption types;
  user = config.users.users.${cfg.user};
  stateDirectory = "${user.home}/.t3";
  runtimePackages = [cfg.package pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.systemd pkgs.git] ++ cfg.path;
in {
  options.services.t3-code = {
    enable = lib.mkEnableOption "Nix-managed private T3 Code backend";
    package = mkOption {
      type = types.package;
      description = "T3 package providing bin/t3. The package's default program may be its desktop GUI.";
    };
    user = mkOption {
      type = types.strMatching "[a-z_][a-z0-9_-]*";
      default = "agent";
      description = "Existing unprivileged account owning T3 state and provider processes.";
    };
    port = mkOption {
      type = types.port;
      default = 3773;
      description = "Loopback HTTP/WebSocket port. This module never opens the firewall.";
    };
    workingDirectory = mkOption {
      type = types.str;
      default = user.home;
      description = "Existing backend working directory; individual threads choose their project directories.";
    };
    path = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Provider and developer packages available without reading an interactive shell profile.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root" && user.isNormalUser && user.home != "/";
        message = "T3 Code requires an existing normal user with a private home, not root.";
      }
      {
        assertion = cfg.port >= 1024;
        message = "T3 Code must use an unprivileged loopback port.";
      }
    ];

    environment.etc."t3code/policy.json" = {
      user = "root";
      group = "root";
      mode = "0444";
      text = builtins.toJSON {
        schemaVersion = 1;
        organization = "4Nix";
        settings =
          lib.genAttrs [
            "continueThreadsAfterServerUpdate"
            "enableProviderUpdateChecks"
            "enableAgentBrowserAccess"
          ] (_: {
            value = false;
            locked = true;
          });
        limits = {
          clients = ["local-browser" "remote"];
          connect = false;
          telemetry = false;
          webhookTasks = false;
          browserCookieImport = false;
          updates.mode = "off";
          providers.allowedDrivers = ["pi" "acpRegistry"];
        };
      };
    };

    systemd.services.t3-code = {
      description = "Private T3 Code backend";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment = {
        HOME = user.home;
        T3CODE_HOME = stateDirectory;
        # NixOS also defines service PATH. Supply the full runtime explicitly,
        # with pinned provider binaries before mutable user profile tools.
        PATH = lib.mkForce "${lib.makeBinPath runtimePackages}:${user.home}/.cargo/bin:/etc/profiles/per-user/${cfg.user}/bin:/run/current-system/sw/bin";
      };
      serviceConfig = {
        User = cfg.user;
        Group = user.group;
        WorkingDirectory = cfg.workingDirectory;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        # Pairing output must not enter the system journal.
        StandardOutput = "null";
        # Only generic launcher failures reach the journal. The application
        # opens its stderr log after systemd has dropped privileges.
        StandardError = "journal";
      };
      script = ''
        set -euo pipefail
        umask 077
        state=${lib.escapeShellArg stateDirectory}
        for directory in "$state" "$state/logs"; do
          if [[ -L "$directory" ]]; then
            printf '%s\n' 'Refusing a symlink in the T3 state/log path.' >&2
            exit 1
          fi
          install -d -m 0700 -- "$directory"
        done
        log="$state/logs/service.stderr.log"
        if [[ -L "$log" ]]; then
          printf '%s\n' 'Refusing a symlink for the T3 stderr log.' >&2
          exit 1
        fi
        touch -- "$log"
        chmod 0600 -- "$log"
        exec ${lib.getExe' cfg.package "t3"} serve \
          --host 127.0.0.1 --port ${toString cfg.port} \
          --base-dir "$state" 2>>"$log"
      '';
    };
  };
}
