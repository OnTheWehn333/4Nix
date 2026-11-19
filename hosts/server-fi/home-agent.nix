{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./home-common.nix ../../home-modules/herdr-core.nix ../../home-modules/pi.nix];

  # T3 supplies the Pi binary and Pi owns its runtime settings.
  custom.pi.skills.enable = true;

  # Home Manager owns the Git config; gh owns the login, not this file.
  programs.git.settings.credential."https://github.com".helper = [
    ""
    "${pkgs.gh}/bin/gh auth git-credential"
  ];

  programs.git.settings.user = {
    name = lib.mkForce "Agent";
    email = lib.mkForce "agent@server-fi";
  };

  # Do not inherit the operator's signing identity.
  programs.git.signing.signByDefault = lib.mkForce false;
}
