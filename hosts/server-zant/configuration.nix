{
  config,
  pkgs,
  ...
}: let
  sshHostKeys = import ../shared/ssh-public-keys.nix;
  serverZantSecretsFile = ../../secrets/server-zant/secrets.yaml;
in {
  imports = [
    ./hardware-configuration.nix
    ./incus.nix
  ];

  networking.hostName = "server-zant";
  networking.networkmanager.enable = true;

  # HP ProLiant DL380p Gen8 currently boots XCP-ng from this local logical volume.
  # Only apply the server-zant disko layout when intentionally retiring/wiping XCP-ng.
  boot.loader.grub.enable = true;
  boot.zfs.forceImportRoot = false;

  nix = {settings = {experimental-features = ["nix-command" "flakes"];};};

  sops = {
    defaultSopsFile = serverZantSecretsFile;
    age.sshKeyPaths = [];
    gnupg = {
      home = "/home/noahbalboa66/.gnupg";
      sshKeyPaths = [];
    };

    secrets."truenas-incus-api-key" = {};

    templates."truenas-incus-ctl-config" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = builtins.toJSON {
        hosts.truenas = {
          url = "wss://192.168.1.88:443/api/current";
          api_key = config.sops.placeholder."truenas-incus-api-key";
          allow_insecure = true;
        };
      };
    };
  };

  programs.zsh.enable = true;

  users.users.noahbalboa66 = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "incus-admin"];
    packages = [];
    shell = pkgs.zsh;
  };

  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.tailscale.enable = true;

  users.users.noahbalboa66.openssh.authorizedKeys.keys = builtins.filter (key: key != "") [
    sshHostKeys.pc-hylia
    sshHostKeys.pc-akkala
  ];

  environment.systemPackages = with pkgs; [
    curl
    dmidecode
    git
    tmux
    vim
  ];

  home-manager.users.noahbalboa66 = import ./home.nix;

  system.stateVersion = "26.05";
}
