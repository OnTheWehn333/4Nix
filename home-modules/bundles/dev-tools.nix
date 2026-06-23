{pkgs, ...}: let
  pythonWithPip = pkgs.python3.withPackages (pythonPackages:
    with pythonPackages; [
      pip
      setuptools
      wheel
    ]);
in {
  imports = [../git.nix ../lazygit.nix ../neovim.nix ../rust.nix ../dotnet.nix];

  # Additional dev tools not in separate files
  home.packages = with pkgs; [jq curl postgresql_16 pythonWithPip zip unzip];
}
