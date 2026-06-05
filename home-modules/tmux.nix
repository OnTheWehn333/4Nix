{
  config,
  lib,
  pkgs,
  ...
}: {
  # fzf powers native fuzzy session switching; Ghostty terminfo keeps tmux
  # working when SSH'ing from ghostty.
  home.packages = with pkgs;
    [fzf]
    ++ lib.optionals (!stdenv.isDarwin) [ghostty.terminfo];

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
      set -g extended-keys on
      set -g extended-keys-format csi-u

      # Use vi-style keys in copy mode and command prompt editing
      setw -g mode-keys vi
      set -g status-keys vi

      # Window/pane settings
      setw -g automatic-rename on
      set-option -g renumber-windows on
      setw -g pane-base-index 1

      # Pane borders: make the active pane easier to spot than Tokyo Night's
      # default border styling, especially in side-by-side splits.
      set -g pane-border-style fg=colour238
      set -g pane-active-border-style fg=#7aa2f7,bold
      set -g pane-border-lines heavy
      set -g pane-border-indicators both
      set -g pane-border-status top
      set -g pane-border-format " #{?pane_active,#[fg=#7aa2f7,bold],#[fg=colour244]}#{pane_index}: #{pane_current_command} "

      bind-key -n C-S-Left swap-window -t -1\; select-window -t -1
      bind-key -n C-S-Right swap-window -t +1\; select-window -t +1

      # Status bar
      set -g status-right '%a %Y-%m-%d %H:%M'
      set -g status-right-length 20

      # Tokyo Night: expose the last/recent-window marker as a user option so
      # hooks can swap the placeholder without rewriting the full status format.
      set -g @custom-tmux-last-window-icon '●'
      run-shell 'tmux set -g window-status-format "$(tmux show -gqv window-status-format | sed "s/󰁯/##{@custom-tmux-last-window-icon}/g")"'

      # Enable OSC 52 clipboard passthrough
      set -g set-clipboard external
      set -g allow-passthrough all

      # Key bindings
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
      bind z switch-client -l
      bind u display-popup -E 'session="$(tmux list-sessions -F "#{session_name}" | fzf --prompt="session> ")" && [ -n "$session" ] && tmux switch-client -t "$session"'
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
          set -g @sessionx-bind 'U'
          set -g @sessionx-layout 'reverse'
        '';
      }
      {
        plugin = tokyo-night-tmux;
        extraConfig = ''
          set -g @tokyo-night-tmux_theme 'night'
          set -g @tokyo-night-tmux_show_hostname 0

          # Use plain window numbers instead of segmented digit glyphs, which
          # are poorly supported by many terminal fonts.
          set -g @tokyo-night-tmux_window_id_style 'none'
        '';
      }
    ];
  };
}
