{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks."*" = {
      # Keep connections alive across idle periods / NAT timeouts
      serverAliveInterval = 60;
      serverAliveCountMax = 3;

      extraOptions = {
        AddKeysToAgent = "yes";
      };
    };
  };
}
