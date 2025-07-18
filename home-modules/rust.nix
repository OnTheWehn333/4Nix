{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [rustup];

  home.activation.setupRustup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! ${pkgs.rustup}/bin/rustup show active-toolchain >/dev/null 2>&1; then
      echo "[rust] Setting up default stable toolchain"
      ${pkgs.rustup}/bin/rustup default stable
    fi
  '';
}
