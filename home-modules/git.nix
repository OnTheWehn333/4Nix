{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    settings.user = {
      name = "noahbalboa66";
      email = "noahwehn@gmail.com";
    };
  };
}
