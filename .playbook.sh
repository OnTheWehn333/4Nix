# 4Nix shortcuts. From the repo root, send one command at a time in Tome.
# Do not run this file as a script.

# Inspect outputs, evaluate checks, or run the checks with builds.
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
nix flake check --no-write-lock-file

# Hylia: build first, then switch after reviewing the changes.
nh darwin build . -H pc-hylia
nh darwin switch . -H pc-hylia --ask

# NixOS: run on the named host. Choose one action.
# build leaves the system alone; test activates until reboot.
# boot selects the next boot generation; switch activates now and at boot.

# Akkala (WSL)
nh os build . -H pc-akkala
nh os test . -H pc-akkala
nh os boot . -H pc-akkala
nh os switch . -H pc-akkala --ask

# Tenoko
nh os build . -H server-tenoko
nh os test . -H server-tenoko
nh os boot . -H server-tenoko
nh os switch . -H server-tenoko --ask

# Zant
nh os build . -H server-zant
nh os test . -H server-zant
nh os boot . -H server-zant
nh os switch . -H server-zant --ask

# Fi: deploy from Hylia. Build and activate on Fi.
nh os switch "$HOME/Projects/4Nix" -H server-fi --build-host server-fi --target-host server-fi --elevation-strategy passwordless --ask --no-write-lock-file

# Fi: administrator shell or unprivileged agent shell.
ssh server-fi
ssh agent@server-fi

# T3: leave this tunnel open on Hylia while using the Mac app.
ssh -nNT -o ExitOnForwardFailure=yes -L 127.0.0.1:13773:127.0.0.1:3773 server-fi

# Incus: list instances on the configured Zant remote.
incus list zant:

# If nh is missing, open a shell with it or use the local rebuild fallback.
nix shell nixpkgs#nh
darwin-rebuild switch --flake .#pc-hylia
sudo nixos-rebuild switch --flake .#pc-akkala
sudo nixos-rebuild switch --flake .#server-tenoko

# Bootstrap only. Run the matching command on the target host.
darwin-rebuild switch --flake .#pc-hylia-bootstrap
sudo nixos-rebuild switch --flake .#pc-akkala-bootstrap
sudo nixos-rebuild switch --flake .#server-tenoko-bootstrap

# Update all flake inputs, or choose one input below.
nix flake update
nix flake update nixpkgs
nix flake update nixpkgs-darwin
nix flake update home-manager
nix flake update home-manager-darwin
nix flake update nix-darwin

# Clean old user generations.
nh clean user --keep 3 --keep-since 14d

# Sign in to 1Password or edit secrets manually. Set the host in Tome first.
op signin
$<host>=pc-hylia
sops secrets/$<host>/secrets.yaml
sops secrets/shared/secrets.yaml

# Keysync: choose backup, sync, or restore. Confirm the host before restoring.
keysync backup --config keysync.yaml --all
keysync sync --config keysync.yaml --all
$<restore_host>=pc-hylia
keysync restore --config keysync.yaml --host $<restore_host>
gpg --list-keys --keyid-format long --with-subkey-fingerprint

# Keysync development: run from the repo root.
(cd tools/keysync && go build ./cmd/keysync/)
(cd tools/keysync && go vet ./...)
(cd tools/keysync && go test ./...)
