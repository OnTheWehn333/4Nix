{
  config,
  lib,
  pkgs,
  ...
}: let
  keysync = pkgs.buildGoModule {
    pname = "keysync";
    version = "0.1.0";
    src = ../tools/keysync;
    vendorHash = "sha256-komX1AmHt2NoF1x6xsNa2RFkfVzOXfYEMPhT0zwMxjw=";
    doCheck = false;

    meta = with lib; {
      mainProgram = "keysync";
      description = "GPG subkey sync to 1Password per host";
      homepage = "https://github.com/OnTheWehn333/keysync";
      license = licenses.mit;
    };
  };
in {
  home.packages = with pkgs; [
    keysync
    _1password-cli
    gnupg
    gpg-tui
  ];
}
