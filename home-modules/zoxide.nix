{ config, ... }:

{
  programs.zoxide = {
    enable = true;
    enableZshIntegration = config.programs.zsh.enable;
    enableNushellIntegration = config.programs.nushell.enable;
    enableBashIntegration = config.programs.bash.enable;
  };
}

