# home-modules/ranger.nix
{ config, lib, pkgs, ... }:

{
  # Simply install ranger when this module is imported
  home.packages = with pkgs; [ ranger ];
}
