{
  config,
  lib,
  pkgs,
  ...
}: let
  herdrCore = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr-core";
    version = "0.1.21";

    src = pkgs.fetchurl {
      url = "https://releases.herdr.dev/core/0.1.21/herdr-core-linux-x86_64.tar.gz";
      hash = "sha256-eEJHVcEKQN3jigvbVcIKwZcG6a4F7Wj8Ks8fz/DZQcE=";
    };

    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    # The official Linux executable is static. Preserve its published bytes.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-core "$out/bin/herdr-core"
      ln -s herdr-core "$out/bin/hc"
      install -Dm644 LICENSE "$out/share/licenses/herdr-core/LICENSE"
      install -Dm644 THIRD-PARTY-NOTICES "$out/share/licenses/herdr-core/THIRD-PARTY-NOTICES"
      runHook postInstall
    '';

    meta = {
      description = "Persistent terminal runtime for Herdr desktop and mobile";
      homepage = "https://herdr.dev/core/";
      license = with lib.licenses; [asl20 mit];
      mainProgram = "hc";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  };
in {
  home.packages = lib.optionals (pkgs.stdenv.isLinux && pkgs.stdenv.hostPlatform.system == "x86_64-linux") [herdrCore];
}
