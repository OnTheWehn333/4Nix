{pkgs, ...}: {
  # Ghostty terminfo so tmux works when SSH'ing from ghostty
  home.packages = [pkgs.ghostty.terminfo];

  programs.tmux = {
    enable = true;

    # Use Home Manager native options for better integration
    terminal = "screen-256color";
    historyLimit = 50000;
    baseIndex = 1;
    escapeTime = 10;
    keyMode = "vi";
    mouse = false;

    extraConfig = ''
      # Terminal features
      set-option -sa terminal-features ',xterm-256color:RGB'
      set-option -sa terminal-features ',xterm-ghostty:RGB'
      set-option -g focus-events on

      # Use vi-style keys in copy mode and command prompt editing
      setw -g mode-keys vi
      set -g status-keys vi

      # Window/pane settings
      setw -g automatic-rename on
      set-option -g renumber-windows on
      setw -g pane-base-index 1

      bind-key -n C-S-Left swap-window -t -1\; select-window -t -1
      bind-key -n C-S-Right swap-window -t +1\; select-window -t +1

      # Status bar
      set -g status-right '%a %Y-%m-%d %H:%M'
      set -g status-right-length 20

      # Enable OSC 52 clipboard passthrough
      set -g set-clipboard on
      set -g allow-passthrough on
      set -ag terminal-overrides ",*:Ms=\\E]52;c;%p2%s\\7"

      # Key bindings
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
      bind z switch-client -l
      bind k clear-history
      bind f resize-pane -Z

      # Splitting panes
      bind | split-window -h
      bind - split-window -v

      # Arrow key bindings for navigating between panes
      bind -n C-Left select-pane -L
      bind -n C-Down select-pane -D
      bind -n C-Up select-pane -U
      bind -n C-Right select-pane -R
    '';

    plugins = with pkgs.tmuxPlugins; [
      resurrect
      tome
      {
        plugin = yank;
        extraConfig = ''
          # Configure yank clipboard target
          set -g @yank_selection 'clipboard'
          set -g @yank_selection_mouse 'clipboard'
        '';
      }
      {
        plugin = tmux-sessionx;
        extraConfig = ''
          set -g @sessionx-bind 'u'
          set -g @sessionx-layout 'reverse'
        '';
      }
      {
        plugin = tokyo-night-tmux;
        extraConfig = ''
          set -g @theme_variation 'night'
        '';
      }
    ];
  };
}
