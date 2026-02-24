{ config, lib, pkgs, ... }:
let
  dotnet-combined = with pkgs.dotnetCorePackages; combinePackages [
    sdk_8_0
    sdk_9_0
  ];
in {
  home.packages = with pkgs; [
    dotnet-combined
    csharpier
    roslyn-ls
    netcoredbg
  ];
  home.sessionVariables = {
    DOTNET_ROOT = "${dotnet-combined}";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
  };
}
