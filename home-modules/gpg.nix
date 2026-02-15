{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    gnupg
    gpg-tui
  ];

  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
  };
}
