{ config, lib, pkgs, ... }:

{
  programs.oh-my-posh = {
    enable = true;
    enableNushellIntegration = true;
    useTheme = "kushal";
  };
}
