{
  config,
  pkgs,
  ...
}: {
  xdg.configFile."ghostty/config".text = ''
    background-opacity = 0.9
    
    # Enable clipboard integration for OSC 52
    clipboard-read = allow
    clipboard-write = allow
    
    # Optional: Configure clipboard behavior
    clipboard-trim-trailing-spaces = true
  '';
}
