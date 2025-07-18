{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nushell = {
    enable = true;
    settings = {
      buffer_editor = "vim";
      edit_mode = "vi";
    };
  };

  home.sessionVariables = {
    EDITOR = "vim";
  };
}
