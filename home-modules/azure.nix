{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [
    azure-cli
    azure-storage-azcopy
    bicep
  ];
  home.sessionVariables = {
    AZURE_CORE_COLLECT_TELEMETRY = "0";
  };
}
