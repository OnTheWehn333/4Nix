{
  description = "NixOS + nix-darwin flake with Home Manager";

  inputs = {
    nixpkgs.url      = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin.url   = "github:LnL7/nix-darwin";
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }:
  let
    # ordinary pkgs for Linux
    linuxPkgs = import nixpkgs { system = "x86_64-linux"; };

    # pkgs for macOS (overlay optional but handy)
    darwinPkgs = import nixpkgs {
      system   = "aarch64-darwin";
      overlays = [ nix-darwin.overlays.default ];
    };
  in {
    ####################################################
    ## NixOS host
    nixosConfigurations.server-tenoko =
      linuxPkgs.lib.nixosSystem {
        system  = "x86_64-linux";
        modules = [
          ./hosts/server-tenoko/configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.config.allowUnfree   = true;
            home-manager.useGlobalPkgs   = true;
            home-manager.useUserPackages = true;
          }
        ];
      };

    ####################################################
    ## macOS host  — **use nix-darwin.lib.darwinSystem**
    darwinConfigurations.pc-hylia =
      nix-darwin.lib.darwinSystem {
        system  = "aarch64-darwin";
        pkgs    = darwinPkgs;                      # <- hand over pkgs
        modules = [
          (import ./hosts/pc-hylia/configuration.nix)
          home-manager.darwinModules.home-manager
          {
            nixpkgs.config.allowUnfree   = true;
            home-manager.useGlobalPkgs   = true;
            home-manager.useUserPackages = true;
          }
        ];
      };
  };
}

