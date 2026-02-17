{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    signing.signByDefault = true;
    settings.user = {
      name = "noahbalboa66";
      email = "noahwehn@gmail.com";
    };
  };
}
