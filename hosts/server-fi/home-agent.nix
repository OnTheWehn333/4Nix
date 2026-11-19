{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./home-common.nix ../../home-modules/herdr-core.nix];

  programs.git.settings.user = {
    name = lib.mkForce "Agent";
    email = lib.mkForce "agent@server-fi";
  };

  # Do not inherit the operator's signing identity.
  programs.git.signing.signByDefault = lib.mkForce false;
}
