{
  config,
  lib,
  pkgs,
  ...
}: let
  hmUsers = config.home-manager.users or {};
  userNames = builtins.attrNames hmUsers;

  isHeadlessUser = userName:
    let
      obsidian = hmUsers.${userName}.services.obsidian or null;
    in
      obsidian != null && obsidian.enable && obsidian.syncMode == "headless";

  headlessUserNames = lib.filter isHeadlessUser userNames;
  singleHeadlessUser = builtins.length headlessUserNames == 1;

  userHome = userName: config.users.users.${userName}.home or "/home/${userName}";
  userGroup = userName: config.users.users.${userName}.group or "users";

  npmGlobalPrefix = userName:
    let
      homeDirectory = userHome userName;
    in
      hmUsers.${userName}.node.npmGlobalPrefix or "${homeDirectory}/.local/share/npm";

  vaultPath = userName: vaultName:
    let
      obsidian = hmUsers.${userName}.services.obsidian;
    in
      "${userHome userName}/${obsidian.baseDir}/${vaultName}";

  serviceName = userName: vaultName:
    if singleHeadlessUser
    then "obsidian-${vaultName}"
    else "obsidian-${userName}-${vaultName}";

  servicePrefix = userName:
    if singleHeadlessUser
    then "obsidian-"
    else "obsidian-${userName}-";

  mkVaultService = userName: vaultName:
    let
      homeDirectory = userHome userName;
      npmPrefix = npmGlobalPrefix userName;
      path = vaultPath userName vaultName;
    in {
      description = "Obsidian Headless Sync (${vaultName})";
      after = ["network-online.target" "home-manager-${userName}.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = userName;
        Group = userGroup userName;
        WorkingDirectory = path;
        ExecStart = "${npmPrefix}/bin/ob sync --continuous --path ${path}";
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = [
          "HOME=${homeDirectory}"
          "PATH=${lib.makeBinPath [pkgs.nodejs_22 pkgs.coreutils]}:${npmPrefix}/bin"
        ];
      };
    };

  mkUserServices = userName:
    let
      obsidian = hmUsers.${userName}.services.obsidian;
      prefix = servicePrefix userName;
    in
      lib.genAttrs (map (serviceName userName) obsidian.vaults) (name:
        mkVaultService userName (lib.removePrefix prefix name));

  allServices = lib.foldl' (acc: userName: acc // mkUserServices userName) {} headlessUserNames;

  tmpfilesRules = lib.concatMap (userName:
    let
      obsidian = hmUsers.${userName}.services.obsidian;
      group = userGroup userName;
    in
      map (vaultName: "d ${vaultPath userName vaultName} 0755 ${userName} ${group} - -") obsidian.vaults
  ) headlessUserNames;
in {
  # Bridge Home Manager `services.obsidian.syncMode = "headless"` into
  # NixOS system services. GUI and none modes intentionally create no services.
  config = {
    systemd.tmpfiles.rules = tmpfilesRules;
    systemd.services = allServices;
  };
}
