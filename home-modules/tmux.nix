{ config, lib, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    extraConfig = ''
      set -g default-terminal "screen-256color" 
      set-option -sa terminal-features ',xterm-256color:RGB'
      set-option -sg escape-time 10
      set-option -g focus-events on
      set -g history-limit 50000
      setw -g automatic-rename
      set-option -g renumber-windows on
      setw -g mode-keys vi
      set -g base-index 1
      setw -g pane-base-index 1
      set -g status-right '%a %Y-%m-%d %H:%M'
      set -g status-right-length 20
      bind r source-file ~/.tmux.conf
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
      yank
      {
        plugin = tmux-sessionx;
        extraConfig = ''
            set -g @sessionx-bind 'o'
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

