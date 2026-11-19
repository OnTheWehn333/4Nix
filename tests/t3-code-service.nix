{pkgs}: let
  fakePi = pkgs.writeShellScriptBin "pi" ''
    printf '%s\n' 'fixture-pi'
  '';
  fakeHermes = pkgs.writeShellScriptBin "hermes" ''
    printf '%s\n' 'fixture-hermes'
  '';
  fakeServer = pkgs.writeText "fake-t3-server.py" ''
    import argparse
    import http.server
    import json
    import os
    from pathlib import Path
    import subprocess
    import sys

    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["serve"])
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--base-dir", required=True)
    args = parser.parse_args()
    policy = json.loads(Path("/etc/t3code/policy.json").read_text())
    state = Path(args.base_dir) / "userdata"
    state.mkdir(mode=0o700, exist_ok=True)
    (state / "runtime.json").write_text(json.dumps({
        "uid": os.getuid(),
        "home": os.environ["HOME"],
        "cwd": os.getcwd(),
        "pi": subprocess.check_output(["pi", "--version"], text=True).strip(),
        "hermes": subprocess.check_output(["hermes", "--version"], text=True).strip(),
        "updates": policy["limits"]["updates"]["mode"],
        "continue": policy["settings"]["continueThreadsAfterServerUpdate"]["value"],
    }))
    print("FAKE_PAIRING_OUTPUT_NOT_FOR_JOURNAL", flush=True)
    print("fixture-private-stderr", file=sys.stderr, flush=True)

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"fixture-ready")
        def log_message(self, *args):
            pass

    http.server.HTTPServer((args.host, args.port), Handler).serve_forever()
  '';
  fakeT3 = pkgs.writeShellScriptBin "t3" ''
    exec ${pkgs.python3}/bin/python3 ${fakeServer} "$@"
  '';
in
  pkgs.testers.runNixOSTest {
    name = "t3-code-private-service";
    nodes.machine = {
      imports = [../modules/t3-code.nix];
      users.users = {
        agent = {
          isNormalUser = true;
          uid = 1000;
          home = "/home/agent";
          homeMode = "0700";
        };
        outsider.isNormalUser = true;
      };
      services.t3-code = {
        enable = true;
        package = fakeT3;
        user = "agent";
        workingDirectory = "/home/agent/workspace";
        path = [fakePi fakeHermes];
      };
      systemd.tmpfiles.rules = ["d /home/agent/workspace 0700 agent users -"];
      environment.systemPackages = [pkgs.curl pkgs.jq pkgs.iproute2];
      system.stateVersion = "26.05";
    };
    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("t3-code.service")
      machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3773 | grep -Fx fixture-ready")
      machine.succeed("ss -ltn | grep -F '127.0.0.1:3773'")
      machine.fail("ss -ltn | grep -E '(0.0.0.0|\\*|\\[::\\]):3773'")
      machine.succeed("jq -e '.uid == 1000 and .home == \"/home/agent\" and .cwd == \"/home/agent/workspace\" and .pi == \"fixture-pi\" and .hermes == \"fixture-hermes\" and .updates == \"off\" and .continue == false' /home/agent/.t3/userdata/runtime.json")
      for path in ["/home/agent/.t3", "/home/agent/.t3/logs", "/home/agent/.t3/userdata"]:
          machine.succeed(f"test $(stat -c %u:%a {path}) = 1000:700")
          machine.fail(f"runuser -u outsider -- test -r {path}")
      machine.succeed("test $(stat -c %u:%a /home/agent/.t3/logs/service.stderr.log) = 1000:600")
      machine.succeed("grep -F fixture-private-stderr /home/agent/.t3/logs/service.stderr.log")
      machine.fail("journalctl -u t3-code.service --no-pager | grep -E 'FAKE_PAIRING_OUTPUT_NOT_FOR_JOURNAL|fixture-private-stderr'")
      machine.fail("runuser -u agent -- test -w /etc/t3code/policy.json")
      machine.succeed("test $(stat -Lc %U:%a /etc/t3code/policy.json) = root:444")
      machine.succeed("systemctl is-enabled t3-code.service")

      # Preserve an independent sentinel, not a file recreated by the server.
      machine.succeed("runuser -u agent -- sh -c 'printf preserve-fixture > /home/agent/.t3/userdata/keep'")
      machine.succeed("systemctl restart t3-code.service")
      machine.wait_until_succeeds("curl -fsS http://127.0.0.1:3773 | grep -Fx fixture-ready")
      machine.succeed("grep -Fx preserve-fixture /home/agent/.t3/userdata/keep")

      # Log files are opened by the unprivileged launcher, never PID 1.
      machine.succeed("systemctl stop t3-code.service")
      machine.succeed("printf preserve > /root/t3-log-target")
      machine.succeed("rm /home/agent/.t3/logs/service.stderr.log; ln -s /root/t3-log-target /home/agent/.t3/logs/service.stderr.log")
      machine.execute("systemctl start t3-code.service")
      machine.wait_until_succeeds("journalctl -u t3-code.service --no-pager | grep -F 'Refusing a symlink for the T3 stderr log.'")
      machine.succeed("systemctl stop t3-code.service")
      machine.succeed("test $(cat /root/t3-log-target) = preserve")
    '';
  }
