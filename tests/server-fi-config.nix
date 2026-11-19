{
  pkgs,
  config,
}: let
  inherit (pkgs) lib;
  cfg = config;
  agent = cfg.users.users.agent;
  agentGroups = [agent.group] ++ agent.extraGroups;
  sudoGrantsAgent = rule:
    builtins.elem "agent" rule.users
    || builtins.elem "ALL" rule.users
    || lib.any (group: builtins.elem group agentGroups) rule.groups;
  requirements = {
    "shared agent identity preserves UID and uses its new home" =
      agent.uid
      == 1000
      && agent.group == "users"
      && agent.home == "/home/agent"
      && agent.linger
      && !(cfg.users.users ? hermes)
      && lib.hasInfix "Match User agent" cfg.services.openssh.extraConfig
      && lib.hasInfix "AllowAgentForwarding no" cfg.services.openssh.extraConfig
      && lib.hasInfix "AllowTcpForwarding no" cfg.services.openssh.extraConfig;
    "key-only SSH without a general firewall opening" =
      cfg.services.openssh.enable
      && !cfg.services.openssh.openFirewall
      && !cfg.services.openssh.settings.PasswordAuthentication
      && !cfg.services.openssh.settings.KbdInteractiveAuthentication
      && cfg.networking.firewall.enable
      && cfg.networking.nftables.enable
      && cfg.networking.firewall.allowedTCPPorts == []
      && cfg.networking.firewall.allowedTCPPortRanges == []
      && lib.all (interface: interface == "lo") cfg.networking.firewall.trustedInterfaces
      && lib.hasInfix "ip saddr 10.100.0.1 tcp dport 22 accept" cfg.networking.firewall.extraInputRules;
    "locked root console and no root SSH" =
      cfg.services.openssh.settings.PermitRootLogin
      == "no"
      && cfg.services.getty.autologinUser == null
      && cfg.users.users.root.initialHashedPassword == "!";
    "keyed administrator and agent access" =
      cfg.users.users.noahbalboa66.openssh.authorizedKeys.keys
      != []
      && agent.openssh.authorizedKeys.keys != []
      && cfg.services.openssh.settings.AllowUsers == ["noahbalboa66" "agent"];
    "private unprivileged agent account" =
      agent.homeMode
      == "0700"
      && lib.all (group: builtins.elem group ["users" "obsidian-vault" "obsidian-vault-4V2"]) agentGroups
      && !(lib.any sudoGrantsAgent cfg.security.sudo.extraRules)
      # NixOS adds Defaults directives here. Reject textual grants/includes
      # that would bypass the structured-rule check above.
      && lib.all (line: builtins.match "[[:space:]]*(#.*|Defaults.*)?" line != null)
      (lib.splitString "\n" cfg.security.sudo.extraConfig);
    "interactive Hermes and session entry point" =
      lib.any (package: (package.pname or "") == "hermes-agent") agent.packages
      && lib.any (package: lib.getName package == "hermes-session") agent.packages
      && !(cfg.systemd.services ? hermes-agent)
      && !(cfg.systemd.services ? hermes)
      && !(cfg.systemd.services ? agent)
      && !(cfg.systemd.services ? herdr-core);
    "T3 backend shares only the unprivileged agent runtime" =
      cfg.services.t3-code.enable
      && cfg.services.t3-code.user == "agent"
      && cfg.services.t3-code.port == 3773
      && cfg.systemd.services.t3-code.serviceConfig.User == "agent"
      && cfg.systemd.services.t3-code.serviceConfig.NoNewPrivileges
      && cfg.systemd.services.t3-code.environment.HOME == agent.home;
    "Herdr core belongs to the agent profile only" =
      lib.any (package: (package.pname or "") == "herdr-core") cfg.home-manager.users.agent.home.packages
      && !(lib.any (package: (package.pname or "") == "herdr-core") cfg.home-manager.users.noahbalboa66.home.packages);
    "both user profiles and vault home links" =
      cfg.home-manager.users ? noahbalboa66
      && cfg.home-manager.users ? agent
      && !(cfg.home-manager.users ? hermes)
      && cfg.home-manager.users.agent.home.username == "agent"
      && cfg.home-manager.users.agent.home.homeDirectory == "/home/agent"
      && cfg.home-manager.users.agent.programs.git.settings.user.name == "Agent"
      && cfg.home-manager.users.agent.programs.git.settings.user.email == "agent@server-fi"
      && !cfg.home-manager.users.agent.programs.git.signing.signByDefault
      && cfg.home-manager.users.noahbalboa66.home.file."ObsidianVaults/4V2".enable
      && cfg.home-manager.users.agent.home.file."ObsidianVaults/4V2".enable;
    "private sync identity and gated shared vault" =
      cfg.services.obsidian-headless.enable
      && cfg.users.users.obsidian-sync.isSystemUser
      && cfg.users.users.obsidian-sync.homeMode == "0700"
      && cfg.users.users.obsidian-sync.group == "obsidian-sync"
      && cfg.systemd.services.obsidian-4V2.serviceConfig.User == "obsidian-sync"
      && cfg.systemd.services.obsidian-4V2.serviceConfig.WorkingDirectory == "/srv/obsidian/4V2"
      && cfg.systemd.services.obsidian-4V2.unitConfig.ConditionPathExists == "/var/lib/obsidian-sync/4V2.ready";
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) requirements);
in
  assert lib.assertMsg (failures == []) "Fi policy check failed: ${lib.concatStringsSep "; " failures}";
    pkgs.runCommand "server-fi-config-check" {} "touch $out"
