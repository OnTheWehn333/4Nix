{
  pkgs,
  config,
}: let
  inherit (pkgs) lib;
  service = config.systemd.services.t3-code or null;
  agentPackages = config.users.users.agent.packages;
  policyFile = config.environment.etc."t3code/policy.json" or null;
  policy =
    if policyFile == null
    then null
    else builtins.fromJSON policyFile.text;
  requirements = {
    "Fi agent Git uses gh for github.com HTTPS credentials" =
      (config.home-manager.users.agent.programs.git.settings.credential."https://github.com".helper or [])
      == ["" "${pkgs.gh}/bin/gh auth git-credential"];
    "T3 starts automatically as the existing private agent" =
      service
      != null
      && builtins.elem "multi-user.target" service.wantedBy
      && service.serviceConfig.User == "agent"
      && service.environment.HOME == "/home/agent"
      && service.serviceConfig.UMask == "0077"
      && config.users.users.agent.uid == 1000;
    "service uses the headless loopback entry and private application output" =
      service
      != null
      && service.serviceConfig.StandardOutput == "null"
      && service.serviceConfig.StandardError == "journal"
      && service.serviceConfig.NoNewPrivileges
      && service.serviceConfig.WorkingDirectory == "/home/agent/workspace"
      && lib.hasInfix "/bin/t3 serve" service.script
      && lib.hasInfix "--host 127.0.0.1 --port 3773" service.script
      && lib.hasInfix "2>>\"$log\"" service.script
      && lib.hasInfix "/etc/profiles/per-user/agent/bin" service.environment.PATH
      && builtins.elem "home-manager-agent.service" service.after
      && config.networking.firewall.allowedTCPPorts == [];
    "root policy prevents unmanaged updates and automatic work" =
      policy
      != null
      && policy.schemaVersion == 1
      && policyFile.user == "root"
      && policyFile.group == "root"
      && policyFile.mode == "0444"
      && policy.limits.updates.mode == "off"
      && !policy.limits.connect
      && !policy.limits.telemetry
      && !policy.limits.webhookTasks
      && !policy.limits.browserCookieImport
      && builtins.elem "remote" policy.limits.clients
      && policy.limits.providers.allowedDrivers == ["pi" "acpRegistry"]
      && !policy.settings.continueThreadsAfterServerUpdate.value
      && policy.settings.continueThreadsAfterServerUpdate.locked
      && !policy.settings.enableProviderUpdateChecks.value
      && policy.settings.enableProviderUpdateChecks.locked
      && !policy.settings.enableAgentBrowserAccess.value
      && policy.settings.enableAgentBrowserAccess.locked;
    "Fi agent gets Pi skills without replacing runtime settings" = let
      home = config.home-manager.users.agent;
      skills = home.programs.agent-skills or {};
      selected = skills.skills.enable or [];
    in
      (skills.enable or false)
      && (skills.targets.pi.enable or false)
      && lib.all (id: builtins.elem id selected) [
        "mattpocock/productivity/grill-me"
        "mattpocock/productivity/grilling"
        "mattpocock/engineering/grill-with-docs"
      ]
      && !(home.home.file ? ".pi/agent/settings.json")
      && !(config.home-manager.users.noahbalboa66.programs.agent-skills.targets.pi.enable or false);
    "only the agent receives the selected backend and Pi" = let
      has = name: version: lib.any (p: (p.pname or "") == name && p.version == version) agentPackages;
    in
      has "t3code" "0.1.8"
      && has "pi-coding-agent" "1.5.2"
      && !(lib.any (p: builtins.elem (p.pname or "") ["t3code" "pi-coding-agent"]) config.users.users.noahbalboa66.packages);
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) requirements);
in
  assert lib.assertMsg (failures == []) "T3 configuration check failed: ${lib.concatStringsSep "; " failures}";
    pkgs.runCommand "t3-code-config-check" {} "touch $out"
