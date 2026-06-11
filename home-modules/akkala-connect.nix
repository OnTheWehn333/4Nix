{ config, lib, pkgs, ... }: let
  akkalaConnect = pkgs.writeShellApplication {
    name = "akkala-connect";
    text = ''
      distro="''${1:-nixos}"
      case "$distro" in
        ""|*[!A-Za-z0-9._-]*)
          echo "Invalid WSL distro name: $distro" >&2
          exit 64
          ;;
      esac

      ssh -tt pc-akkala.local -- "wsl -d $distro -- bash -lc \"tmux has-session -t noahbalboa66 2>/dev/null || tmux new-session -d -s noahbalboa66; exec tmux attach-session -t noahbalboa66\""
    '';
  };
in {
  home.packages = [ akkalaConnect ];
  home.shellAliases = {
    akkala = "akkala-connect nixos";
    akkala-ubuntu = "akkala-connect ubuntu";
  };
}
