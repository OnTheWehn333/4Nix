{
  config,
  pkgs,
  ...
}: {
  xdg.configFile."ghostty/config".text = ''
    # Use a widely available TERM for tmux compatibility
    term = xterm-256color

    background-opacity = 0.9
    
    # Enable clipboard integration for OSC 52
    clipboard-read = allow
    clipboard-write = allow
    
    # Optional: Configure clipboard behavior
    clipboard-trim-trailing-spaces = true
  '';
}
