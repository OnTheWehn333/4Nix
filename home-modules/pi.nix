{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.custom.pi;

  piSettings = cfg.settings // {
    packages = cfg.packages;
  };
in {
  # Import agent-skills-nix at module level so its options are available
  imports = [
    inputs.agent-skills-nix.homeManagerModules.default
  ];

  options.custom.pi = {
    enable = lib.mkEnableOption "Pi coding agent - AI coding CLI";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [];
      description = "Pi packages to load from ~/.pi/agent/settings.json.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional Pi settings written to ~/.pi/agent/settings.json.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.agent-skills = {
      enable = true;

      sources.obsidian = {
        input = "kepano-obsidian-skills";
        subdir = "skills";
        idPrefix = "obsidian";
      };

      skills.enable = [
        "obsidian/obsidian-markdown"
        "obsidian/obsidian-bases"
        "obsidian/json-canvas"
        "obsidian/obsidian-cli"
        "obsidian/defuddle"
      ];

      targets.pi = {
        enable = true;
        dest = "\${HOME}/.pi/agent/skills";
        structure = "symlink-tree";
      };
    };

    home.file.".pi/agent/settings.json".text = lib.generators.toJSON {} piSettings;

    home.activation.checkPiAvailable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ! command -v pi &>/dev/null; then
        echo "WARNING: 'pi' command not found."
        echo "         Pi coding agent is managed via npm global packages."
        echo "         Install with: npm install -g @mariozechner/pi-coding-agent"
        echo "         It will be installed to: ${config.node.npmGlobalPrefix}/bin"
      fi
    '';
  };
}
