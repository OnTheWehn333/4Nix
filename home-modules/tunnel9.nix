{
  config,
  lib,
  pkgs,
  ...
}:
let
  tunnel9 = pkgs.buildGoModule {
    pname = "tunnel9";
    version = "1.0.3";
    src = pkgs.fetchFromGitHub {
      owner = "sio2boss";
      repo = "tunnel9";
      rev = "78e18557c8521e5446d49826bd7cedf19b188019";
      hash = "sha256-jxg9swaNroBN8tUBtxyKa9K3syt6gSJauYkWXj6/ikA=";
    };
    vendorHash = "sha256-QIe2U5v6Bo+9E2X+Vg/94JN9K0jpNtYsiHgx+bw3jvQ=";
    doCheck = false;

    meta = with lib; {
      mainProgram = "tunnel9";
      description = "Terminal UI for managing SSH tunnels";
      homepage = "https://github.com/sio2boss/tunnel9";
      license = licenses.mit;
    };
  };
in {
  home.packages = [tunnel9];
}
