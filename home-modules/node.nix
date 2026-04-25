{
  config,
  lib,
  pkgs,
  ...
}: let
  # Map version string to nodejs package
  nodejsVersionMap = {
    "18" = pkgs.nodejs_18;
    "20" = pkgs.nodejs_20;
    "22" = pkgs.nodejs_22;
  };
in let
  defaultNodejs = nodejsVersionMap.${config.node.defaultVersion} or pkgs.nodejs_22;
in {
  options.node = {
    defaultVersion = lib.mkOption {
      type = lib.types.enum [ "18" "20" "22" ];
      default = "22";
      description = "Default Node.js version for interactive use and global npm packages";
    };
  };

  config = {
    home.packages = with pkgs; [
      # Global npm packages - built independently of nodejs version
      # These work with any nodejs version since they're standalone CLI tools
      yarn

      # Add global tools here as needed, e.g.:
      # nodePackages.typescript
      # nodePackages.prettier
      # nodePackages.eslint

      # Default nodejs version for interactive use (node, npm, npx)
      # Modules can still bring their own nodejs version when needed
      defaultNodejs
    ];
  };
}
