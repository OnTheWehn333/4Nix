{
  pkgs,
  lib,
  ...
}: let
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
                      then seg // {background = "#7aa2f7";} # Tokyo Night blue accent
                      else seg
                  )
                  block.segments;
              }
            else block
        )
        orig.blocks;
    };
in {
  programs.oh-my-posh = {
    enable = true;
    enableNushellIntegration = true;
    settings = custom;
  };
}
