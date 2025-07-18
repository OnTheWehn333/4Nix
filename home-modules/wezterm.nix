{
  lib,
  pkgs,
  ...
}: {
  programs.wezterm = {
    enable = false;

    # this block gets written to ~/.config/wezterm/wezterm.lua
    extraConfig = ''
      local config = {}

      -- ~80% window transparency
      config.window_background_opacity = 0.3

      -- same opacity for the text-background
      config.text_background_opacity = 0.3

      -- force RGBA background color so it blends
      config.colors = {
        background = "rgba(17,17,17,0.3)"
      }
      return {
          keys = {
              {key="LeftArrow",  mods="CTRL", action=wezterm.action.SendString("\x1b[1;5D")},
              {key="RightArrow", mods="CTRL", action=wezterm.action.SendString("\x1b[1;5C")},
              {key="UpArrow",    mods="CTRL", action=wezterm.action.SendString("\x1b[1;5A")},
              {key="DownArrow",  mods="CTRL", action=wezterm.action.SendString("\x1b[1;5B")},
          },
      }

      return config
    '';
  };
}
