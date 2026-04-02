{ config, lib, pkgs, ... }:
let
  dotnet-combined = with pkgs.dotnetCorePackages; combinePackages [
    sdk_10_0
    sdk_9_0
    sdk_8_0
  ];
in {
  home.packages = with pkgs; [
    dotnet-combined
    csharpier
    roslyn-ls
    netcoredbg
    httpgenerator
  ];
  home.sessionPath = [
    "${config.home.homeDirectory}/.dotnet/tools"
  ];
  home.sessionVariables = {
    DOTNET_ROOT = "${dotnet-combined}";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    # Allow roll-forward to handle apps targeting different framework versions
    DOTNET_ROLL_FORWARD = "LatestMinor";
  };
}
