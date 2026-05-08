{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.custom.agent-runner;
  package = inputs.agent-runner.packages.${pkgs.stdenv.hostPlatform.system}.agent-runner;
in {
  imports = [ ];

  options.custom.agent-runner.enable = lib.mkEnableOption "agent-runner Pi package";

  config = lib.mkIf cfg.enable {
    custom.pi.enable = true;
    home.file.".pi/agent/packages/agent-runner".source = package;
    custom.pi.packages = lib.mkAfter ["./packages/agent-runner"];
  };
}
