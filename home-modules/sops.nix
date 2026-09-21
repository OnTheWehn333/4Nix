{
  config,
  lib,
  pkgs,
  ...
}: let
  hostAgeRecipient = pkgs.writeShellApplication {
    name = "4nix-host-age-recipient";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.openssh
      pkgs.ssh-to-age
    ];
    text = builtins.readFile ./scripts/4nix-host-age-recipient.sh;
  };
in {
  home.packages = with pkgs; [
    hostAgeRecipient
    sops
  ];
}
