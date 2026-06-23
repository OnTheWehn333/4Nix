{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = with pkgs; [
    stats
  ];

  launchd.agents.stats = {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe pkgs.stats)
      ];

      RunAtLoad = true;
      KeepAlive = {
        Crashed = true;
      };
    };
  };
}
