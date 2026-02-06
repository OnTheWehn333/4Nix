{
  description = "NixOS + nix-darwin flake with Home Manager";

  inputs = {
    # Linux nixpkgs (for NixOS + HM on Linux)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Darwin nixpkgs (for nix-darwin + HM on macOS)
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";

    # Home Manager for Linux
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager for macOS
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # nix-darwin matching the darwin nixpkgs release
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };


  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    home-manager-darwin,
    nix-darwin,
    ...
  }: let
    # Get the overlay functions from overlays/default.nix
    overlays = import ./overlays {inherit inputs;};

    overlaysList = [
      overlays.unstable-packages # defines pkgs.unstable
      overlays.modifications # uses pkgs.unstable.tmux
    ];

    linuxPkgs = import nixpkgs {
      system = "x86_64-linux";
      config = {allowUnfree = true;};
      overlays = overlaysList;
    };

    darwinPkgs = import nixpkgs {
      system = "aarch64-darwin";
      overlays = [nix-darwin.overlays.default] ++ overlaysList;
    };
  in {
    ####################################################
    ## NixOS host
    nixosConfigurations.server-tenoko = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      modules = [
        ./hosts/server-tenoko/configuration.nix
        ./modules/tak-server.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ];
    };

    ####################################################
    ## macOS host  — **use nix-darwin.lib.darwinSystem**
    darwinConfigurations.pc-hylia = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      pkgs = darwinPkgs; # <- hand over pkgs
      modules = [
        (import ./hosts/pc-hylia/configuration.nix)
        home-manager-darwin.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ];
    };
  };
}
