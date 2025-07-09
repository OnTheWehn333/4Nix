{ config, lib, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "noahbalboa66";
    userEmail = "noahwehn@gmail.com";
  };
  # programs.ssh = {
  #   extraConfig = ''
  #     Host *
  #         IdentityAgent ~/.1password/agent.sock
  #   '';
  # };
}
