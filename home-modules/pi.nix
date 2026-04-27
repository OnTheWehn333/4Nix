{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.custom.pi;
in {
  # Import agent-skills-nix at module level so its options are available
  imports = [
    inputs.agent-skills-nix.homeManagerModules.default
  ];

  options.custom.pi = {
    enable = lib.mkEnableOption "Pi coding agent - AI coding CLI";
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
