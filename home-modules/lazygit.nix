{pkgs, ...}: let
  lazygitWithGpgUnlock = pkgs.writeShellApplication {
    name = "lazygit";
    runtimeInputs = with pkgs; [gnupg];
    text = ''
      echo | gpg --clearsign >/dev/null
      exec ${pkgs.lazygit}/bin/lazygit "$@"
    '';
  };
in {
  imports = [
    ./gpg.nix
  ];

  programs.lazygit = {
    enable = true;
    package = lazygitWithGpgUnlock;
  };
}
