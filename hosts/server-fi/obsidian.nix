{
  config,
  lib,
  pkgs,
  ...
}: {
  # The common module owns accounts, credentials, permissions and services.
  services.obsidian-headless = {
    enable = true;
    vaults."4V2".editors = ["noahbalboa66" "agent"];
  };
}
