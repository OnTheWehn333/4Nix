{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  cfg = config.services.obsidian-headless;
  inherit (lib) mkIf mkOption types;
  absolutePath = types.strMatching "/[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)*";
  relativePath = types.strMatching "[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)*";
  safePath = path: lib.all (part: part != "." && part != "..") (lib.splitString "/" path);
  containsPath = parent: child: parent == child || lib.hasPrefix "${parent}/" child;
  pathsOverlap = left: right: containsPath left right || containsPath right left;
  vaults = lib.attrValues cfg.vaults;
  editors = lib.unique (lib.concatMap (vault: vault.editors) vaults);
  # Invalid identities still fail assertions, but must not overwrite the
  # private account or generate a root Home Manager profile while evaluating.
  configuredEditors = lib.filter (editor: editor != "root" && editor != cfg.user) editors;
  hasHomeManager = options ? home-manager;
  syncFileTypes = ["image" "audio" "video" "pdf" "unsupported"];
  vaultGroup = name: "${cfg.group}-${name}";
  editorGroups = editor:
    [cfg.group] ++ map vaultGroup (lib.filter (name: builtins.elem editor cfg.vaults.${name}.editors) (lib.attrNames cfg.vaults));

  mkVaultService = name: vault: {
    description = "Obsidian Sync for ${name}";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    unitConfig = lib.optionalAttrs (vault.readinessMarker != null) {
      ConditionPathExists = vault.readinessMarker;
    };
    environment = {
      HOME = cfg.stateDirectory;
      XDG_CONFIG_HOME = "${cfg.stateDirectory}/.config";
    };
    serviceConfig = {
      User = cfg.user;
      Group = cfg.user;
      SupplementaryGroups = [cfg.group (vaultGroup name)];
      WorkingDirectory = vault.path;
      ExecStartPre = lib.escapeShellArgs [
        (lib.getExe' cfg.package "ob")
        "sync-config"
        "--path"
        vault.path
        "--mode"
        vault.mode
        "--file-types"
        (lib.concatStringsSep "," vault.fileTypes)
        "--configs"
        (lib.concatStringsSep "," vault.configs)
      ];
      ExecStart = lib.escapeShellArgs [(lib.getExe' cfg.package "ob") "sync" "--continuous" "--path" vault.path];
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0007";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [cfg.stateDirectory vault.path];
    };
  };
in {
  options.services.obsidian-headless = {
    enable = lib.mkEnableOption "dedicated-account Obsidian headless sync";
    package = lib.mkPackageOption pkgs "obsidian-headless" {};
    user = mkOption {
      type = types.strMatching "[a-z_][a-z0-9_-]*";
      default = "obsidian-sync";
      description = "Private system account and primary group for sync credentials and processes.";
    };
    group = mkOption {
      type = types.strMatching "[a-z_][a-z0-9_-]*";
      default = "obsidian-vault";
      description = "Parent-directory traversal group and prefix for per-vault editor groups. These groups never grant credential access.";
    };
    stateDirectory = mkOption {
      type = absolutePath;
      default = "/var/lib/${cfg.user}";
      description = "Private persistent home for authentication state and readiness markers.";
    };
    baseDirectory = mkOption {
      type = absolutePath;
      default = "/srv/obsidian";
      description = "Parent directory used by default vault paths. Paths must not contain whitespace or parent traversal.";
    };
    vaults = mkOption {
      default = {};
      description = "Headless vault inventory. Each editor needs a NixOS account and a Home Manager profile.";
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          path = mkOption {
            type = absolutePath;
            default = "${cfg.baseDirectory}/${name}";
            description = "Shared vault directory outside user homes.";
          };
          editors = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Existing login users with read/write access to this vault and a home link.";
          };
          homeLink = mkOption {
            type = relativePath;
            default = "ObsidianVaults/${name}";
            description = "Link path relative to each editor's home. Existing non-symlinks must be moved aside manually.";
          };
          readinessMarker = mkOption {
            type = types.nullOr absolutePath;
            default = "${cfg.stateDirectory}/${name}.ready";
            description = "Marker created manually after authentication and first sync. Null disables the startup gate.";
          };
          mode = mkOption {
            type = types.enum ["bidirectional" "pull-only" "mirror-remote"];
            default = "bidirectional";
            description = "Sync mode accepted by the selected Obsidian Headless client.";
          };
          fileTypes = mkOption {
            type = types.listOf (types.enum syncFileTypes);
            default = syncFileTypes;
            description = "Attachment categories to sync.";
          };
          configs = mkOption {
            type = types.listOf (types.enum ["app" "appearance" "appearance-data" "hotkey" "core-plugin" "core-plugin-data" "community-plugin" "community-plugin-data"]);
            default = [];
            description = "Settings/plugin categories accepted by the client. Empty disables their sync.";
          };
        };
      }));
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.user != cfg.group && cfg.user != "root";
          message = "Obsidian sync needs a private non-root account and a separate shared vault group.";
        }
        {
          assertion = lib.all (name: builtins.match "[a-zA-Z0-9][a-zA-Z0-9._-]*" name != null) (lib.attrNames cfg.vaults);
          message = "Obsidian vault names must be safe directory and systemd unit name components.";
        }
        {
          assertion = lib.all safePath ([cfg.stateDirectory cfg.baseDirectory] ++ lib.concatMap (vault: [vault.path vault.homeLink] ++ lib.optional (vault.readinessMarker != null) vault.readinessMarker) vaults);
          message = "Obsidian paths must not contain parent traversal.";
        }
        {
          assertion =
            !(pathsOverlap cfg.stateDirectory cfg.baseDirectory)
            && lib.all (vault: !(pathsOverlap cfg.stateDirectory vault.path)) vaults;
          message = "Obsidian shared directories and private credential state must not overlap.";
        }
        {
          assertion = lib.all (vault: vault.readinessMarker == null || lib.hasPrefix "${cfg.stateDirectory}/" vault.readinessMarker) vaults;
          message = "Obsidian readiness markers must be inside the private sync state directory.";
        }
        {
          assertion = lib.all (left: lib.all (right: left == right || !(pathsOverlap cfg.vaults.${left}.path cfg.vaults.${right}.path)) (lib.attrNames cfg.vaults)) (lib.attrNames cfg.vaults);
          message = "Each Obsidian sync service needs a distinct non-overlapping vault path.";
        }
        {
          assertion = lib.all (left: lib.all (right: left == right || !(pathsOverlap cfg.vaults.${left}.homeLink cfg.vaults.${right}.homeLink)) (lib.attrNames cfg.vaults)) (lib.attrNames cfg.vaults);
          message = "Each Obsidian vault needs a distinct non-overlapping editor home link.";
        }
        {
          assertion = lib.all (vault: !(containsPath vault.path cfg.baseDirectory)) vaults;
          message = "Obsidian vaults must not replace the shared parent directory or its ancestors.";
        }
        {
          assertion = lib.all (name: builtins.stringLength (vaultGroup name) <= 32 && vaultGroup name != cfg.user) (lib.attrNames cfg.vaults);
          message = "Obsidian generated vault groups must fit Linux group names and differ from the private sync group.";
        }
        {
          assertion = lib.all (editor: editor != cfg.user && (config.users.users.${editor}.isNormalUser or false)) editors;
          message = "Obsidian editors must be existing normal users, distinct from the private sync account.";
        }
        {
          assertion = editors == [] || hasHomeManager;
          message = "Obsidian editor home links require the NixOS Home Manager module.";
        }
        {
          assertion = lib.all (path: !(containsPath "/home" path) && !(containsPath "/root" path)) ([cfg.stateDirectory cfg.baseDirectory] ++ map (vault: vault.path) vaults);
          message = "Shared Obsidian vaults must be outside user homes because the sync process uses ProtectHome.";
        }
      ];

      users.groups = lib.genAttrs ([cfg.user cfg.group] ++ map vaultGroup (lib.attrNames cfg.vaults)) (_: {});
      users.users =
        {
          ${cfg.user} = {
            isSystemUser = true;
            group = cfg.user;
            extraGroups = [cfg.group] ++ map vaultGroup (lib.attrNames cfg.vaults);
            home = cfg.stateDirectory;
            homeMode = "0700";
            createHome = true;
          };
        }
        // lib.genAttrs configuredEditors (editor: {extraGroups = editorGroups editor;});

      environment.systemPackages = [cfg.package];
      systemd.tmpfiles.rules =
        [
          "d ${cfg.stateDirectory} 0700 ${cfg.user} ${cfg.user} -"
          "d ${cfg.baseDirectory} 0750 root ${cfg.group} -"
        ]
        ++ lib.concatMap (name: let
          vault = cfg.vaults.${name};
        in [
          "d ${vault.path} 2770 ${cfg.user} ${vaultGroup name} -"
          # Default ACLs preserve ordinary shared writes even with umask 077.
          # Explicit chmod or restrictive creation modes can still remove access.
          "a+ ${vault.path} - - - - d:u::rwx,d:g::rwx,d:m::rwx,d:o::---"
        ]) (lib.attrNames cfg.vaults);
      systemd.services = lib.mapAttrs' (name: vault: lib.nameValuePair "obsidian-${name}" (mkVaultService name vault)) cfg.vaults;
    }

    (lib.optionalAttrs hasHomeManager {
      home-manager.users = lib.genAttrs configuredEditors (editor: {
        config,
        lib,
        ...
      }: let
        editorVaults = lib.filter (vault: builtins.elem editor vault.editors) vaults;
      in {
        home.file = lib.listToAttrs (map (vault:
          lib.nameValuePair vault.homeLink {
            source = config.lib.file.mkOutOfStoreSymlink vault.path;
          })
        editorVaults);
        # Run before HM's normal collision handling, even when a host enables
        # backupFileExtension. Never rename a real vault during activation.
        home.activation.checkObsidianVaultLinks = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
          for relative_path in ${lib.escapeShellArgs (map (vault: vault.homeLink) editorVaults)}; do
            if [[ -e "$HOME/$relative_path" && ! -L "$HOME/$relative_path" ]]; then
              echo "Refusing to replace Obsidian vault at $HOME/$relative_path. Preserve it and move it aside manually before activation." >&2
              exit 1
            fi
          done
        '';
      });
    })
  ]);
}
