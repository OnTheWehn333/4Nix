{ config, lib, pkgs, ... }: let
  akkalaConnect = pkgs.writeShellApplication {
    name = "akkala-connect";
    text = ''
      distro="''${1:-nixos}"
      ssh -t pc-akkala.local wsl -d "$distro" -- tmux new-session -A -s "noahbalboa66"
    '';
  };
in {
  home.packages = [ akkalaConnect ];
  home.shellAliases = {
    akkala = "akkala-connect nixos";
    akkala-ubuntu = "akkala-connect ubuntu";
  };
}
