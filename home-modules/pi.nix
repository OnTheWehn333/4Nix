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

    skills.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      defaultText = lib.literalExpression "config.custom.pi.enable";
      description = "Install the shared Pi skill catalog independently of Pi settings.";
    };

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

  config = {
    programs.agent-skills = lib.mkIf cfg.skills.enable {
      enable = true;

      sources.obsidian = {
        input = "kepano-obsidian-skills";
        subdir = "skills";
        idPrefix = "obsidian";
      };

      sources.cursor = {
        input = "cursor-plugins";
        subdir = "pstack/skills";
        idPrefix = "cursor";
      };

      sources.mattpocock = {
        input = "mattpocock-skills";
        subdir = "skills";
        idPrefix = "mattpocock";
      };

      # Explicit selection: upstream updates must not silently add more skills.
      skills.enable = [
        "obsidian/obsidian-markdown"
        "obsidian/obsidian-bases"
        "obsidian/json-canvas"
        "obsidian/obsidian-cli"
        "obsidian/defuddle"

        "cursor/unslop"

        # Matt Pocock: engineering and productivity only (no misc/in-progress).
        "mattpocock/engineering/ask-matt"
        "mattpocock/engineering/code-review"
        "mattpocock/engineering/codebase-design"
        "mattpocock/engineering/diagnosing-bugs"
        "mattpocock/engineering/domain-modeling"
        "mattpocock/engineering/grill-with-docs"
        "mattpocock/engineering/implement"
        "mattpocock/engineering/improve-codebase-architecture"
        "mattpocock/engineering/prototype"
        "mattpocock/engineering/research"
        "mattpocock/engineering/resolving-merge-conflicts"
        "mattpocock/engineering/setup-matt-pocock-skills"
        "mattpocock/engineering/tdd"
        "mattpocock/engineering/to-spec"
        "mattpocock/engineering/to-tickets"
        "mattpocock/engineering/triage"
        "mattpocock/engineering/wayfinder"
        "mattpocock/engineering/wizard"
        "mattpocock/productivity/grill-me"
        "mattpocock/productivity/grilling"
        "mattpocock/productivity/handoff"
        "mattpocock/productivity/teach"
        "mattpocock/productivity/to-questionnaire"
        "mattpocock/productivity/wait-what"
        "mattpocock/productivity/writing-for-agents"
      ];

      targets.pi.enable = true;
    };

    home = lib.mkIf cfg.enable {
      file.".pi/agent/settings.json".text = lib.generators.toJSON {} piSettings;

      file.".pi/agent/APPEND_SYSTEM.md".text = lib.mkAfter ''
        Before your first response, read ~/.pi/agent/skills/cursor/unslop/SKILL.md.
        Apply its writing rules to every response and authored prose throughout the session.
        If those rules are no longer in context, read the file again before responding.
        Preserve technical accuracy, literal code, commands, identifiers, and quotations.
      '';

      activation.checkPiAvailable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ! command -v pi &>/dev/null; then
          echo "WARNING: 'pi' command not found."
          echo "         Pi coding agent is managed via npm global packages."
          echo "         Install with: npm install -g @mariozechner/pi-coding-agent"
          echo "         It will be installed to: ${config.node.npmGlobalPrefix}/bin"
        fi
      '';
    };
  };
}
