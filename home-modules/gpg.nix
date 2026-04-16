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
  programs.gpg.settings = {
    pinentry-mode = "loopback";
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-tty;
    extraConfig = ''
      allow-loopback-pinentry
    '';
  };

  # Ensure GPG_TTY is set and the agent targets the current terminal. A plain TTY
  # prompt is more reliable than curses inside TUIs like lazygit.
  programs.bash.initExtra = lib.mkBefore ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
  '';
  programs.zsh.initContent = lib.mkBefore ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
  '';
  programs.nushell.extraEnv = lib.mkBefore ''
    $env.GPG_TTY = (^tty | str trim)
    ^gpg-connect-agent updatestartuptty /bye out+err> /dev/null
  '';
}
