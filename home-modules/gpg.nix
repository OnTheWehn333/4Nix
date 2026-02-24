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

  # Ensure gpg-agent can find the current terminal for pinentry.
  # This is required for SSH sessions and non-local TTYs.
  programs.bash.initExtra = ''
    export GPG_TTY=$(tty)
  '';
  programs.zsh.initContent = ''
    export GPG_TTY=$(tty)
  '';

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
