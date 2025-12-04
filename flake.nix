{
  description = "NixOS + nix-darwin flake with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin.url = "github:LnL7/nix-darwin";
  };

  outputs = inputs@{ nixpkgs, home-manager, nix-darwin, ... }:
    let

      # Get the overlay functions from overlays/default.nix
      overlays = import ./overlays { inherit inputs; };

      overlaysList = [
        overlays.unstable-packages # defines pkgs.unstable
        overlays.modifications # uses pkgs.unstable.tmux
      ];

      linuxPkgs = import nixpkgs {
        system = "x86_64-linux";
        config = { allowUnfree = true; };
        overlays = overlaysList;
      };

      darwinPkgs = import nixpkgs {
        system = "aarch64-darwin";
        overlays = [ nix-darwin.overlays.default ] ++ overlaysList;
      };
    in {
      ####################################################
      ## NixOS host
      nixosConfigurations.server-tenoko = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        pkgs = linuxPkgs;
        modules = [
          ./hosts/server-tenoko/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
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
          home-manager.darwinModules.home-manager
          {
            nixpkgs.config.allowUnfree = true;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };
    };

    darwinPkgs = import nixpkgs {
      system = "aarch64-darwin";
      overlays = [nix-darwin.overlays.default];
      config = {allowUnfree = true;};
    };
  in {
    ####################################################
    ## NixOS host
    nixosConfigurations.server-tenoko = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      modules = [
        ./hosts/server-tenoko/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
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
        home-manager.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];
    };
  };
}
