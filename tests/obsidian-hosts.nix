{
  pkgs,
  configurations,
}: let
  inherit (pkgs) lib;
  akkala = configurations.pc-akkala.config;
  fi = configurations.server-fi.config;
  bootstrap = configurations.pc-akkala-bootstrap.config;
  checkVault = cfg: name: editors: let
    unit = cfg.systemd.services."obsidian-${name}";
    vault = cfg.services.obsidian-headless.vaults.${name};
  in
    unit.serviceConfig.User
    == "obsidian-sync"
    && unit.serviceConfig.Group == "obsidian-sync"
    && unit.serviceConfig.WorkingDirectory == "/srv/obsidian/${name}"
    && unit.unitConfig.ConditionPathExists == "/var/lib/obsidian-sync/${name}.ready"
    && unit.environment.HOME == "/var/lib/obsidian-sync"
    && unit.serviceConfig.ProtectHome
    && unit.serviceConfig.ProtectSystem == "strict"
    && unit.serviceConfig.ReadWritePaths == ["/var/lib/obsidian-sync" "/srv/obsidian/${name}"]
    && vault.mode == "bidirectional"
    && vault.configs == []
    && builtins.elem "unsupported" vault.fileTypes
    && lib.sort builtins.lessThan vault.editors == lib.sort builtins.lessThan editors
    && lib.all (editor: cfg.home-manager.users.${editor}.home.file."ObsidianVaults/${name}".enable) editors;
  requirements = {
    "Akkala must sync 4V2 as the private sync account, not its login user" = checkVault akkala "4V2" ["noahbalboa66"];
    "Akkala must sync 4Vault with the same private-account defaults" = checkVault akkala "4Vault" ["noahbalboa66"];
    "Fi must keep both editors on the shared 4V2 vault" = checkVault fi "4V2" ["noahbalboa66" "agent"];
    "both hosts must use a private system account without login credentials or sudo groups" = lib.all (cfg:
      cfg.users.users.obsidian-sync.isSystemUser
      && cfg.users.users.obsidian-sync.homeMode == "0700"
      && cfg.users.users.obsidian-sync.openssh.authorizedKeys.keys == []
      && !(builtins.elem "wheel" cfg.users.users.obsidian-sync.extraGroups)
      && !(builtins.elem "docker" cfg.users.users.obsidian-sync.extraGroups)
      && lib.hasSuffix "/nologin" (cfg.users.users.obsidian-sync.shell.shellPath or (toString cfg.users.users.obsidian-sync.shell))) [akkala fi];
    "Akkala must not retain a competing Home Manager headless inventory" = !akkala.home-manager.users.noahbalboa66.services.obsidian.enable;
    "Akkala bootstrap must not start sync or migrate vault paths" =
      !bootstrap.services.obsidian-headless.enable
      && !(bootstrap.systemd.services ? obsidian-4V2)
      && !(bootstrap.systemd.services ? obsidian-4Vault)
      && !(bootstrap.home-manager.users.noahbalboa66.home.file ? "ObsidianVaults/4V2");
    "all host module assertions must pass" = lib.all (cfg: lib.all (check: check.assertion) cfg.assertions) [akkala fi];
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) requirements);
in
  assert lib.assertMsg (failures == []) "Obsidian host checks failed: ${lib.concatStringsSep "; " failures}";
    pkgs.runCommand "obsidian-hosts-check" {} "touch $out"
