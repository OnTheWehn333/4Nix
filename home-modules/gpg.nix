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
    pinentry.package = pkgs.pinentry-curses;
  };

  # Ensure GPG_TTY is set for all shells — HM's gpg-agent integration may not
  # run early enough (e.g. server-tenoko's bash→nushell exec happens before bashrc).
  programs.bash.initExtra = lib.mkBefore ''
    export GPG_TTY="$(tty)"
  '';
  programs.zsh.initContent = lib.mkBefore ''
    export GPG_TTY="$(tty)"
  '';
  programs.nushell.extraEnv = lib.mkBefore ''
    $env.GPG_TTY = (^tty | str trim)
  '';
}
