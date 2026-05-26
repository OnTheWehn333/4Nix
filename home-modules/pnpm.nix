{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [ pnpm ];
}
