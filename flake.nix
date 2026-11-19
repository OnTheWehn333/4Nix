{
  description = "NixOS + nix-darwin flake with Home Manager";

  inputs = {
    # Linux nixpkgs (for NixOS + HM on Linux)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Only Fi's T3/Pi trial uses this newer package source.
    nixpkgs-t3 = {
      url = "github:NixOS/nixpkgs/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55";
      flake = false;
    };

    # Darwin nixpkgs (for nix-darwin + HM on macOS)
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    # Local development input; replace with a Git URL before remote consumption.
    party-console.url = "path:/Users/noahbalboa66/Projects/party-console";

    # Home Manager for Linux
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager for macOS
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # nix-darwin matching the darwin nixpkgs release
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Declarative, pinned Homebrew installation for macOS
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # NixOS-WSL for WSL hosts
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sops-nix for secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko for declarative disk partitioning/formatting during NixOS installs
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix-darwin = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # agent-skills-nix: Declarative agent skills management
    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # kepano/obsidian-skills: Skills for Obsidian
    kepano-obsidian-skills = {
      url = "github:kepano/obsidian-skills";
      flake = false;
    };

    # Skill content is pinned in flake.lock and selected in home-modules/pi.nix.
    cursor-plugins = {
      url = "github:cursor/plugins";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    # Hermes keeps its own nixpkgs pin for the Python/toolchain versions it needs.
    hermes-agent.url = "github:NousResearch/hermes-agent/v0.23.0";

    # agent-runner: private Pi package for isolated workflow-scoped agent runs
    agent-runner = {
      url = "git+ssh://git@github.com/OnTheWehn333/agent-runner.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    home-manager-darwin,
    nix-darwin,
    nix-homebrew,
    disko,
    ...
  }: let
    # Get the overlay functions from overlays/default.nix
    overlays = import ./overlays {inherit inputs;};

    overlaysList = [
      overlays.unstable-packages # defines pkgs.unstable
      overlays.modifications # uses pkgs.unstable.tmux
    ];

    vimDefaultEditorModule = {pkgs, ...}: {
      environment.systemPackages = [pkgs.vim];
      environment.variables = {
        EDITOR = "vim";
        VISUAL = "vim";
      };
    };

    diagnosticToolsModule = {
      config,
      lib,
      pkgs,
      ...
    }: {
      environment.systemPackages = with pkgs;
        [btop]
        ++ lib.optionals stdenv.isLinux [systemctl-tui];
    };

    linuxPkgs = import nixpkgs {
      system = "x86_64-linux";
      config = {allowUnfree = true;};
      overlays = overlaysList;
    };

    # The fleet pin lacks this package. Reuse the existing locked package set
    # without making the common Obsidian module depend on Hermes.
    obsidianHeadlessModule = {pkgs, ...}: {
      imports = [./modules/obsidian-headless.nix];
      services.obsidian-headless.package =
        (import inputs.hermes-agent.inputs.nixpkgs {
          system = pkgs.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        }).obsidian-headless;
    };

    darwinPkgs = import nixpkgs {
      system = "aarch64-darwin";
      config = {allowUnfree = true;};
      overlays = [nix-darwin.overlays.default] ++ overlaysList;
    };
  in {
    ####################################################
    ## Reusable 4Nix installer/rescue ISO
    nixosConfigurations."4nix-installer" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      specialArgs = {inherit inputs;};
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ./hosts/installer/configuration.nix
      ];
    };

    ####################################################
    ## NixOS host
    nixosConfigurations.server-tenoko = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        ./hosts/server-tenoko/configuration.nix
        ./modules/tak-server.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ];
    };

    ## NixOS bootstrap (minimal HM profile for key restore dependencies)
    nixosConfigurations.server-tenoko-bootstrap = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        ./hosts/server-tenoko/configuration.nix
        ./modules/tak-server.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
        ({lib, ...}: {
          home-manager.users.noahbalboa66 = lib.mkForce (import ./hosts/server-tenoko/home-bootstrap.nix);
        })
      ];
    };

    ## NixOS host: Incus hypervisor replacement for XCP-ng
    nixosConfigurations.server-zant = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        ./hosts/server-zant/disko.nix
        ./hosts/server-zant/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ];
    };

    ## NixOS Incus VM: identity and access services
    nixosConfigurations.server-gohdan = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        "${nixpkgs}/nixos/modules/virtualisation/incus-virtual-machine.nix"
        inputs.sops-nix.nixosModules.sops
        ./hosts/server-gohdan/configuration.nix
        ./modules/authentik.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ];
    };

    # Incus imports VM images as a metadata archive plus a QCOW2 data file.
    # Bundle both under stable names for the OpenTofu provisioning handoff.
    packages.x86_64-linux.server-gohdan-incus-image = let
      cfg = inputs.self.nixosConfigurations.server-gohdan.config;
    in
      linuxPkgs.runCommand "server-gohdan-incus-image" {} ''
        mkdir -p "$out"
        ln -s ${cfg.system.build.qemuImage}/nixos.qcow2 "$out/disk.qcow2"
        ln -s ${cfg.system.build.metadata}/${cfg.image.filePath} "$out/metadata.tar.xz"
      '';

    ## NixOS Incus VM: SSH-first AI agents
    nixosConfigurations.server-fi = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      specialArgs = {inherit inputs;};
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        "${nixpkgs}/nixos/modules/virtualisation/incus-virtual-machine.nix"
        ./hosts/server-fi/configuration.nix
        obsidianHeadlessModule
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
        }
      ];
    };

    packages.x86_64-linux.server-fi-incus-image = let
      cfg = inputs.self.nixosConfigurations.server-fi.config;
    in
      linuxPkgs.runCommand "server-fi-incus-image" {} ''
        mkdir -p "$out"
        ln -s ${cfg.system.build.qemuImage}/nixos.qcow2 "$out/disk.qcow2"
        ln -s ${cfg.system.build.metadata}/${cfg.image.filePath} "$out/metadata.tar.xz"
      '';

    checks.x86_64-linux.server-fi-config = import ./tests/server-fi-config.nix {
      pkgs = linuxPkgs;
      config = inputs.self.nixosConfigurations.server-fi.config;
    };

    checks.x86_64-linux.t3-code-config = import ./tests/t3-code-config.nix {
      pkgs = linuxPkgs;
      config = inputs.self.nixosConfigurations.server-fi.config;
    };

    checks.x86_64-linux.t3-code-service = import ./tests/t3-code-service.nix {
      pkgs = linuxPkgs;
    };

    checks.x86_64-linux.obsidian-headless-config = import ./tests/obsidian-headless-config.nix {
      pkgs = linuxPkgs;
      inherit nixpkgs;
      homeManagerModule = home-manager.nixosModules.home-manager;
    };

    checks.x86_64-linux.obsidian-hosts = import ./tests/obsidian-hosts.nix {
      pkgs = linuxPkgs;
      configurations = inputs.self.nixosConfigurations;
    };

    checks.x86_64-linux.server-fi-vault-permissions = import ./tests/server-fi-vault.nix {
      pkgs = linuxPkgs;
      inherit inputs;
    };

    ####################################################
    ## WSL host
    nixosConfigurations.pc-akkala = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      specialArgs = {inherit inputs;};
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        ./hosts/pc-akkala/configuration.nix
        obsidianHeadlessModule
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ];
    };

    ## WSL bootstrap (minimal HM profile for key restore dependencies)
    nixosConfigurations.pc-akkala-bootstrap = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = linuxPkgs;
      specialArgs = {inherit inputs;};
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        ./hosts/pc-akkala/configuration.nix
        obsidianHeadlessModule
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
        ({lib, ...}: {
          home-manager.users.noahbalboa66 = lib.mkForce (import ./hosts/pc-akkala/home-bootstrap.nix);
          # Bootstrap must not migrate vault paths or start authenticated sync.
          services.obsidian-headless.enable = lib.mkForce false;
        })
      ];
    };

    ####################################################
    ## macOS host
    darwinConfigurations.pc-hylia = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      pkgs = darwinPkgs;
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = "noahbalboa66";
            autoMigrate = true;
          };
        }
        (import ./hosts/pc-hylia/configuration.nix)
        home-manager-darwin.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ];
    };

    ## macOS bootstrap (minimal HM profile for key restore dependencies)
    darwinConfigurations.pc-hylia-bootstrap = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      pkgs = darwinPkgs;
      modules = [
        vimDefaultEditorModule
        diagnosticToolsModule
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = "noahbalboa66";
            autoMigrate = true;
          };
        }
        (import ./hosts/pc-hylia/configuration.nix)
        home-manager-darwin.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
        ({lib, ...}: {
          home-manager.users.noahbalboa66 = lib.mkForce (import ./hosts/pc-hylia/home-bootstrap.nix);
        })
      ];
    };
  };
}
