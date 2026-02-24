{
  config,
  pkgs,
  lib,
  ...
}: let
  hostColor = config.custom.oh-my-posh.hostColor;

  # 1) Load the built-in hul10 theme
  orig = builtins.fromJSON (builtins.readFile "${pkgs.oh-my-posh}/share/oh-my-posh/themes/hul10.omp.json");

  # 2) Override palette.white and the session segment's background
  custom =
    orig
    // {
      palette =
        orig.palette
        // {
          white = "#c0caf5"; # Tokyo Night pale blue
        };

      blocks =
        lib.map (
          block:
            if builtins.hasAttr "segments" block
            then
              block
              // {
                segments =
                  lib.map (
                    seg:
                      if seg.type == "session"
                      then seg // {background = hostColor;}
                      else seg
                  )
                  block.segments;
              }
            else block
        )
        orig.blocks;
    };
in {
  options.custom.oh-my-posh.hostColor = lib.mkOption {
    type = lib.types.str;
    default = "#7aa2f7"; # Tokyo Night blue (Lake Hylia)
    description = ''
      Background color for the oh-my-posh session segment.
      Each host sets this to a Zelda-themed Tokyo Night color.
    '';
  };

  config = {
    programs.oh-my-posh = {
      enable = true;
      enableNushellIntegration = true;
      settings = custom;
    };
  };
}
