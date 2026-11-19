{
  pkgs,
  inputs,
}: let
  # A local fixture, not the real client. No network or credentials are used.
  fixtureClient = pkgs.writeShellScriptBin "ob" ''
    case "$1" in
      sync-config)
        printf '%s\n' "$@" > "$HOME/config-''${PWD##*/}"
        ;;
      sync)
        # Each process may write only its own vault, despite its account
        # having filesystem access to both vaults outside the sandbox.
        if [[ "$PWD" == /srv/obsidian/4V2 ]]; then
          other=/srv/obsidian/4Vault
        else
          other=/srv/obsidian/4V2
        fi
        if ${pkgs.coreutils}/bin/touch "$other/cross-service-write" 2>/dev/null; then
          exit 80
        fi
        printf '%s\n' "$PWD" > "$HOME/running-''${PWD##*/}"
        exec ${pkgs.coreutils}/bin/sleep infinity
        ;;
      *) exit 90 ;;
    esac
  '';
in
  pkgs.testers.runNixOSTest {
    name = "obsidian-headless-vault-permissions";

    nodes.machine = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [
        ../modules/obsidian-headless.nix
        inputs.home-manager.nixosModules.home-manager
      ];
      services.obsidian-headless = {
        enable = true;
        package = fixtureClient;
        vaults = {
          "4V2".editors = ["agent" "noahbalboa66" "collision"];
          "4Vault".editors = ["noahbalboa66"];
        };
      };
      users.users = {
        agent = {
          isNormalUser = true;
          uid = 1000;
          home = "/home/agent";
          homeMode = "0700";
        };
        noahbalboa66.isNormalUser = true;
        collision.isNormalUser = true;
      };
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        users = lib.genAttrs ["agent" "noahbalboa66" "collision"] (_: {
          home.stateVersion = "26.05";
        });
      };
      # Seed the pre-migration directory explicitly in the test, then start
      # activation. Do not race boot-time tmpfiles against this user's unit.
      systemd.services.home-manager-collision.wantedBy = lib.mkForce [];
      environment.systemPackages = with pkgs; [util-linux];
      system.stateVersion = "26.05";
    };

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-agent.service")
      machine.succeed("test $(id -u agent) = 1000 && test $(stat -c %a /home/agent) = 700")
      machine.wait_for_unit("home-manager-noahbalboa66.service")

      # Without markers, neither process may attempt configuration or sync.
      for vault in ["4V2", "4Vault"]:
          machine.succeed(f"systemctl start obsidian-{vault}.service")
          machine.succeed(f"test $(systemctl show obsidian-{vault}.service -p ActiveState --value) = inactive")
          machine.succeed(f"test ! -e /var/lib/obsidian-sync/config-{vault}")

      # Both users reach the same files through their familiar home links.
      for user in ["agent", "noahbalboa66"]:
          machine.succeed(f"test $(readlink -f /home/{user}/ObsidianVaults/4V2) = /srv/obsidian/4V2")
      machine.succeed("test $(readlink -f /home/noahbalboa66/ObsidianVaults/4Vault) = /srv/obsidian/4Vault")

      # Ordinary new files and nested directories remain shared with umask 077.
      machine.succeed("runuser -u agent -- sh -c 'umask 077; mkdir ~/ObsidianVaults/4V2/agent; printf agent > ~/ObsidianVaults/4V2/agent/note.md'")
      machine.succeed("runuser -u obsidian-sync -- sh -c 'cat /srv/obsidian/4V2/agent/note.md; printf sync >> /srv/obsidian/4V2/agent/note.md'")
      machine.succeed("runuser -u obsidian-sync -- sh -c 'umask 077; mkdir /srv/obsidian/4V2/sync; printf sync > /srv/obsidian/4V2/sync/note.md'")
      machine.succeed("runuser -u agent -- sh -c 'cat ~/ObsidianVaults/4V2/sync/note.md; printf agent >> ~/ObsidianVaults/4V2/sync/note.md'")
      machine.succeed("runuser -u noahbalboa66 -- test -w /srv/obsidian/4V2/agent/note.md")
      machine.succeed("runuser -u noahbalboa66 -- sh -c 'umask 077; printf admin > ~/ObsidianVaults/4Vault/note.md'")
      machine.succeed("runuser -u obsidian-sync -- sh -c 'printf sync >> /srv/obsidian/4Vault/note.md'")
      machine.fail("runuser -u agent -- cat /srv/obsidian/4Vault/note.md")
      machine.fail("runuser -u agent -- test -w /srv/obsidian/4Vault")

      # Only a fake credential fixture is present. Editors cannot access it
      # or create readiness markers in the private state directory.
      machine.succeed("install -d -m 0700 -o obsidian-sync -g obsidian-sync /var/lib/obsidian-sync/.config")
      machine.succeed("install -m 0600 -o obsidian-sync -g obsidian-sync /dev/null /var/lib/obsidian-sync/.config/auth-fixture")
      for user in ["agent", "noahbalboa66"]:
          machine.fail(f"runuser -u {user} -- cat /var/lib/obsidian-sync/.config/auth-fixture")
          machine.fail(f"runuser -u {user} -- touch /var/lib/obsidian-sync/4V2.ready")
      machine.succeed("getent passwd obsidian-sync | grep '/nologin$'")

      # A marker releases just that vault. The client fixture checks process
      # write isolation; it cannot write the other vault through its sandbox.
      machine.succeed("touch /var/lib/obsidian-sync/4V2.ready")
      # The migration hold also gates units across configuration reloads,
      # even if a readiness marker already exists. Removing it releases sync.
      machine.succeed("mkdir -p /run/systemd/system/obsidian-4V2.service.d")
      machine.succeed("echo '[Unit]' > /run/systemd/system/obsidian-4V2.service.d/99-cutover-hold.conf; echo 'ConditionPathExists=!/run/obsidian-cutover-hold' >> /run/systemd/system/obsidian-4V2.service.d/99-cutover-hold.conf")
      machine.succeed("touch /run/obsidian-cutover-hold; systemctl daemon-reload; systemctl start obsidian-4V2.service")
      machine.succeed("test $(systemctl show obsidian-4V2.service -p ActiveState --value) = inactive")
      machine.succeed("test ! -e /var/lib/obsidian-sync/config-4V2")
      machine.succeed("rm /run/obsidian-cutover-hold; systemctl start obsidian-4V2.service")
      machine.wait_for_unit("obsidian-4V2.service")
      machine.wait_until_succeeds("test -f /var/lib/obsidian-sync/running-4V2")
      machine.succeed("grep -Fx /srv/obsidian/4V2 /var/lib/obsidian-sync/running-4V2")
      machine.succeed("grep -Fx bidirectional /var/lib/obsidian-sync/config-4V2")
      machine.succeed("grep -Fx image,audio,video,pdf,unsupported /var/lib/obsidian-sync/config-4V2")
      machine.succeed("test $(systemctl show obsidian-4Vault.service -p ActiveState --value) = inactive")
      machine.succeed("test ! -e /srv/obsidian/4Vault/cross-service-write")
      machine.succeed("touch /var/lib/obsidian-sync/4Vault.ready; systemctl start obsidian-4Vault.service")
      machine.wait_for_unit("obsidian-4Vault.service")
      machine.wait_until_succeeds("test -f /var/lib/obsidian-sync/running-4Vault")
      machine.succeed("test ! -e /srv/obsidian/4V2/cross-service-write")

      # Establish the real-directory collision before deliberately starting
      # activation. Verify the fixture first, so a missing setup cannot be
      # misreported as data loss caused by the link guard.
      machine.succeed("test $(systemctl show home-manager-collision.service -p ActiveState --value) = inactive")
      machine.succeed("test ! -e /home/collision/ObsidianVaults/4V2 && test ! -L /home/collision/ObsidianVaults/4V2")
      machine.succeed("install -d -m 0700 -o collision -g users /home/collision/ObsidianVaults")
      machine.succeed("install -d -m 0755 -o collision -g users /home/collision/ObsidianVaults/4V2")
      machine.succeed("runuser -u collision -- sh -c 'printf fixture > /home/collision/ObsidianVaults/4V2/preserve-me'")
      machine.succeed("runuser -u collision -- grep -Fx fixture /home/collision/ObsidianVaults/4V2/preserve-me")
      status, output = machine.execute("systemctl start home-manager-collision.service")
      print(output)
      print(machine.succeed("journalctl -u home-manager-collision.service -n 80 --no-pager"))
      print(machine.succeed("find /home/collision/ObsidianVaults -maxdepth 3 -printf '%y %p\\n'"))
      assert status != 0, "Activation must refuse an existing real vault directory"
      machine.succeed("systemctl is-failed home-manager-collision.service")
      machine.succeed("grep -Fx fixture /home/collision/ObsidianVaults/4V2/preserve-me")
      machine.succeed("test ! -L /home/collision/ObsidianVaults/4V2")
      machine.succeed("test ! -e /home/collision/ObsidianVaults/4V2.hm-backup")
      machine.succeed("journalctl -u home-manager-collision.service | grep -F 'Refusing to replace Obsidian vault'")
    '';
  }
