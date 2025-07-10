{ pkgs, ... }:

let
  # Read in the raw script text
  scriptText = builtins.readFile ./scripts/tmux-sessionizer.sh;

  # Turn it into a real `$PATH` binary
  tmuxSessionizer = pkgs.writeShellScriptBin "tmux-sessionizer" scriptText;
in
{
  home.packages = with pkgs; [ fzf tmuxSessionizer ];
}

