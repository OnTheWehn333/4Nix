{
  config,
  pkgs,
  ...
}: {
  imports = [../git.nix ../neovim.nix ../rust.nix];

  # Additional dev tools not in separate files
  home.packages = with pkgs; [jq curl];
}
