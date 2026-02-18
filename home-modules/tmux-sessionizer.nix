{pkgs, ...}: let
  tmuxSessionizer = pkgs.writeShellApplication {
    name = "tmux-sessionizer";

    # packages your script depends on
    runtimeInputs = [
      pkgs.fzf
      pkgs.tmux
    ];

    text = builtins.readFile ./scripts/tmux-sessionizer.sh;
  };
in {
  home.packages = [tmuxSessionizer];
  home.shellAliases.ts = "tmux-sessionizer";
}
