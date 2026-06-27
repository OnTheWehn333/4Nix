{...}: {
  imports = [
    ../../home-modules/keysync.nix
  ];

  programs.home-manager.enable = true;

  home.stateVersion = "26.05";
}
