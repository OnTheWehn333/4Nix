{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    userName = "noahbalboa66";
    userEmail = "noahwehn@gmail.com";
  };
}
