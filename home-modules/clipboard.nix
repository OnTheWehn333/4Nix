{
  lib,
  pkgs,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;
in {
  home.packages = lib.optionals isLinux (with pkgs; [
    wl-clipboard
    xclip
  ]);
}
