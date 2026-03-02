{
  config,
  lib,
  pkgs,
  ...
}: let
  vaultDir = "${config.home.homeDirectory}/4Vault";
  isDarwin = pkgs.stdenv.isDarwin;
in {
  home.packages = lib.optionals isDarwin [pkgs.obsidian];

  home.activation.setupObsidianVault = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "${vaultDir}" ]; then
      echo "[obsidian] Creating vault directory ${vaultDir}"
      mkdir -p "${vaultDir}"
    fi
  '';
}
