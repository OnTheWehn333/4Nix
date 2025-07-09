{
  description = "NixOS configuration with Home Manager";

  inputs = {
    # Core channels
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    claude-code-nix.url = "git+https://codeberg.org/MachsteNix/claude-code-nix";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    # NixOS configurations
    nixosConfigurations = {
      # VM configuration - make sure this name matches the hostname in your configuration
      "server-tenoko" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux"; # Adjust if needed
        modules = [
          ./hosts/server-tenoko/configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.config.allowUnfree = true;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };
    };
  };
}
