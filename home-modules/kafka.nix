{
  config,
  lib,
  pkgs,
  ...
}: let
  kplay = pkgs.buildGoModule {
    pname = "kplay";
    version = "3.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "dhth";
      repo = "kplay";
      rev = "0a3928d8992b21ecf715e3fd73103a21ed4ceb94";
      hash = "sha256-8MPXHysCDsw4AE/cEQ4s3uagoSmaAm6+YSrd/BATx0g=";
    };
    vendorHash = "sha256-2VopLakz2kmtyTYdgawoRzfRKW6sXtKqIRWRJa52lOw=";
    doCheck = false;

    meta = with lib; {
      mainProgram = "kplay";
      description = "Kafka topic browser and message inspector";
      homepage = "https://github.com/dhth/kplay";
      license = licenses.mit;
    };
  };
in {
  home.packages = [kplay];
}
