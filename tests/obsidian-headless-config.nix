{
  pkgs,
  nixpkgs,
  homeManagerModule,
}: let
  inherit (pkgs) lib;
  fixturePackage = pkgs.writeShellScriptBin "ob" "exit 1";
  evaluate = extra:
    (nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      inherit pkgs;
      modules = [
        ../modules/obsidian-headless.nix
        homeManagerModule
        {
          system.stateVersion = "26.05";
          services.obsidian-headless = {
            enable = true;
            package = fixturePackage;
            vaults.Notes.editors = ["editor"];
          };
          users.users.editor.isNormalUser = true;
          home-manager.users.editor.home.stateVersion = "26.05";
        }
        extra
      ];
    }).config;
  hasFailure = fragment: cfg:
    lib.any (check: !check.assertion && lib.hasInfix fragment check.message) cfg.assertions;
  unsafe = evaluate {
    services.obsidian-headless.vaults.Notes.path = "/var/lib/obsidian-sync/shared";
  };
  overlap = evaluate {
    services.obsidian-headless.vaults.Nested.path = "/srv/obsidian/Notes/nested";
  };
  publicMarker = evaluate {
    services.obsidian-headless.vaults.Notes.readinessMarker = "/srv/obsidian/Notes/ready";
  };
  invalidEditor = evaluate {
    services.obsidian-headless.vaults.Notes.editors = lib.mkForce ["root"];
  };
  traversal = evaluate {
    services.obsidian-headless.vaults.Notes.homeLink = "../Notes";
  };
  disabled = evaluate {services.obsidian-headless.enable = lib.mkForce false;};
  standalone =
    (nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      inherit pkgs;
      modules = [
        ../modules/obsidian-headless.nix
        {
          system.stateVersion = "26.05";
          services.obsidian-headless = {
            enable = true;
            package = fixturePackage;
            vaults.Solo = {};
          };
        }
      ];
    }).config;
  custom = evaluate {
    services.obsidian-headless = {
      user = "vault-sync";
      group = "vault-editors";
      stateDirectory = "/var/lib/vault-auth";
      baseDirectory = "/srv/notes";
      vaults = {
        Notes = {
          path = "/srv/notes/personal";
          homeLink = "Notes/Personal";
          mode = "pull-only";
          fileTypes = ["pdf"];
          configs = ["appearance"];
          readinessMarker = null;
        };
        Assets = {};
      };
    };
  };
  requirements = {
    "shared vaults must not overlap private credential state" = hasFailure "must not overlap" unsafe;
    "separate sync processes must not operate on overlapping paths" = hasFailure "non-overlapping" overlap;
    "editors must not control readiness markers" = hasFailure "readiness markers" publicMarker;
    "root cannot be an editor account" = hasFailure "existing normal users" invalidEditor;
    "home links cannot escape the editor home" = hasFailure "parent traversal" traversal;
    "disabled module must not create accounts, services or links" =
      !(disabled.users.users ? obsidian-sync)
      && !(disabled.systemd.services ? obsidian-Notes)
      && !(disabled.home-manager.users.editor.home.file ? "ObsidianVaults/Notes");
    "sync without editors must not require Home Manager" =
      standalone.systemd.services.obsidian-Solo.serviceConfig.User
      == "obsidian-sync"
      && !(standalone ? home-manager);
    "custom identity, state and paths must configure the process" =
      custom.systemd.services.obsidian-Notes.serviceConfig.User
      == "vault-sync"
      && custom.systemd.services.obsidian-Notes.environment.HOME == "/var/lib/vault-auth"
      && custom.systemd.services.obsidian-Notes.serviceConfig.WorkingDirectory == "/srv/notes/personal"
      && custom.home-manager.users.editor.home.file."Notes/Personal".enable
      && custom.systemd.services.obsidian-Assets.unitConfig.ConditionPathExists == "/var/lib/vault-auth/Assets.ready";
    "readiness gating can be explicitly disabled per vault" = !(custom.systemd.services.obsidian-Notes.unitConfig ? ConditionPathExists);
    "per-vault sync choices reach the client arguments" = lib.hasInfix "--mode pull-only --file-types pdf --configs appearance" custom.systemd.services.obsidian-Notes.serviceConfig.ExecStartPre;
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) requirements);
in
  assert lib.assertMsg (failures == []) "Obsidian module checks failed: ${lib.concatStringsSep "; " failures}";
    pkgs.runCommand "obsidian-headless-config-check" {} "touch $out"
