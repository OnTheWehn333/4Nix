{
  config,
  lib,
  pkgs,
  ...
}: let
  flakePath = "${config.home.homeDirectory}/projects/4Nix";
in {
  programs.nh = {
    enable = true;
    package = pkgs.nh;
    flake = flakePath;

    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 14d";
    };
  };

  home.shellAliases = {
    nhs =
      if pkgs.stdenv.isDarwin
      then "nh darwin switch"
      else "nh os switch";
    nht =
      if pkgs.stdenv.isDarwin
      then "nh darwin test"
      else "nh os test";
    nhb =
      if pkgs.stdenv.isDarwin
      then "nh darwin build"
      else "nh os build";
    nhcu = "nh clean user --keep 5 --keep-since 14d";
  } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
    nhboot = "nh os boot";
  };
}
