{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./home-common.nix];

  programs.git.settings.user = {
    name = lib.mkForce "noahbalboa66";
    email = lib.mkForce "noahwehn@gmail.com";
  };

  # Fi has no signing identity configured for this account yet.
  programs.git.signing.signByDefault = lib.mkForce false;
}
