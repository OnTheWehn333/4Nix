{
  config,
  pkgs,
  ...
}: {
  xdg.configFile."ghostty/config".text = ''
    background-opacity = 0.9
  '';
}
