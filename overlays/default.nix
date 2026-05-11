{inputs, ...}: {
  # Expose nixpkgs-unstable under pkgs.unstable
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  # Packages you want to override live here 👇
  modifications = final: prev: {
    opencode = final.unstable.opencode;
    azure-cli = final.unstable.azure-cli;

    httpgenerator = final.buildDotnetGlobalTool {
      pname = "HttpGenerator";
      version = "1.0.0";
      nugetHash = "sha256-JESESLRyPmcK7XZowL0GOxkezGPBQqsZ54AeaCB4RKQ=";
      dotnet-runtime = final.dotnetCorePackages.runtime_8_0;
      executables = [ "httpgenerator" ];
    };

    tmuxPlugins = prev.tmuxPlugins // {
      tokyo-night-tmux = prev.tmuxPlugins.tokyo-night-tmux.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            substituteInPlace "$out/share/tmux-plugins/tokyo-night-tmux/tokyo-night.tmux" \
              --replace-fail 'tmux set -g window-status-current-format "$RESET#[fg=''${THEME[green]},bg=''${THEME[bblack]}] #{?#{==:#{pane_current_command},ssh},󰣀 ,$active_terminal_icon $window_space}#[fg=''${THEME[foreground]},bold,nodim]$window_number#W#[nobold]#{?window_zoomed_flag, $zoom_number, $custom_pane}#{?window_last_flag, , }"' \
                             'tmux set -g window-status-current-format "$RESET#[fg=''${THEME[foreground]},bg=''${THEME[bblack]},bold,nodim] $window_number#[fg=''${THEME[green]},bg=''${THEME[bblack]}]#{?#{==:#{pane_current_command},ssh},󰣀 ,$active_terminal_icon }#[nobold]#{?window_zoomed_flag,$zoom_number,$custom_pane}#[fg=''${THEME[foreground]},bg=''${THEME[bblack]},bold,nodim]#W#[nobold]#{?window_last_flag, 󰁯,} "' \
              --replace-fail 'tmux set -g window-status-format "$RESET#[fg=''${THEME[foreground]}] #{?#{==:#{pane_current_command},ssh},󰣀 ,$terminal_icon $window_space}''${RESET}$window_number#W#[nobold,dim]#{?window_zoomed_flag, $zoom_number, $custom_pane}#[fg=''${THEME[yellow]}]#{?window_last_flag,󰁯  , }"' \
                             'tmux set -g window-status-format "$RESET''${RESET} $window_number#[fg=''${THEME[foreground]}]#{?#{==:#{pane_current_command},ssh},󰣀 ,$terminal_icon }#[nobold,dim]#{?window_zoomed_flag,$zoom_number,$custom_pane}''${RESET}#W#[fg=''${THEME[yellow]}]#{?window_last_flag, 󰁯,} "'
          '';
      });

      tome = prev.tmuxPlugins.mkTmuxPlugin {
        pluginName = "tome";
        version = "unstable-2025-10-08";
        src = final.fetchFromGitHub {
          owner = "laktak";
          repo = "tome";
          rev = "4c4b31eeb8e8e12d1493a88b3870a257c7d15667";
          hash = "sha256-7ZbaFWQ3bNi2M40xp6cwySuEr0K7cOX1jeX7FwLf6Us=";
        };
      };
    };
  };
}
