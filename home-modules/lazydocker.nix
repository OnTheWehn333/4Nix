# home-modules/ranger.nix
{pkgs, ...}: {
  # Simply install ranger when this module is imported
  home.packages = with pkgs; [lazydocker];
}
