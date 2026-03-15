{
  config,
  pkgs,
  ...
}: {
  imports = [../git.nix ../neovim.nix ../rust.nix ../dotnet.nix];

  # Additional dev tools not in separate files
  programs.lazygit.enable = true;

  home.packages = with pkgs; [jq curl postgresql];
}
