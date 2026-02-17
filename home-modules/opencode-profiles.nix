{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.opencode;
  defaultProfile = "zen";

  # Shared defaults for all profiles — only sisyphus/prometheus change per profile
  defaultAgents = {
    librarian = "google/antigravity-gemini-3-flash";
    explore = "google/antigravity-gemini-3-flash";
    "frontend-ui-ux-engineer" = "google/antigravity-gemini-3-pro-high";
    "document-writer" = "google/antigravity-gemini-3-flash";
    "multimodal-looker" = "google/antigravity-gemini-3-flash";
  };

  profileDefinitions = {
    zen = defaultAgents // {
      sisyphus = "opencode/claude-opus-4-6";
      prometheus = "opencode/claude-opus-4-6";
    };
    copilot = defaultAgents // {
      sisyphus = "github-copilot/claude-opus-4-5";
      prometheus = "github-copilot/claude-opus-4-5";
    };
    anthropic = defaultAgents // {
      sisyphus = "anthropic/claude-opus-4-6";
      prometheus = "anthropic/claude-opus-4-6";
    };
  };

  profileAgentSettings = lib.mapAttrs (_: agents: lib.mapAttrs (_: model: {inherit model;}) agents) profileDefinitions;
  profileNames = builtins.attrNames profileDefinitions;

  mkOhMyOpencodeSettings = agents: {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    google_auth = false;
    agents = agents;
  };

  profileConfigFiles = lib.mapAttrs' (
    profileName: agents:
      lib.nameValuePair "opencode/profiles/${profileName}.json" {
        text = builtins.toJSON (mkOhMyOpencodeSettings agents);
      }
  ) profileAgentSettings;

  opencodeProfile = pkgs.writeShellApplication {
    name = "opencode-profile";
    runtimeInputs = [pkgs.jq];
    text = ''
      set -euo pipefail

      CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      CONFIG_FILE="$CONFIG_HOME/opencode/oh-my-opencode.json"
      PROFILES_DIR="$CONFIG_HOME/opencode/profiles"

      BUILTIN_PROFILES='${builtins.toJSON profileNames}'

      usage() {
        cat <<'EOF'
Usage:
  opencode-profile list
  opencode-profile show
  opencode-profile switch <profile>
EOF
      }

      list_profiles() {
        echo "Built-in profiles:"
        jq -r '.[] | "  - " + .' <<<"$BUILTIN_PROFILES"
      }

      profile_exists() {
        local profile_name
        profile_name="$1"
        jq -e --arg profile "$profile_name" 'index($profile) != null' <<<"$BUILTIN_PROFILES" >/dev/null
      }

      ensure_profile_file() {
        local profile_name
        profile_name="$1"
        local target
        target="$PROFILES_DIR/$profile_name.json"

        if [ ! -f "$target" ]; then
          echo "Error: profile file '$target' not found." >&2
          echo "Run Home Manager once so profile files are generated." >&2
          exit 1
        fi
      }

      show_current_profile() {
        if [ -L "$CONFIG_FILE" ]; then
          local target
          target="$(readlink "$CONFIG_FILE")"
          local profile_name
          profile_name="$(basename "$target" .json)"

          if profile_exists "$profile_name" && [ "$target" = "$PROFILES_DIR/$profile_name.json" ]; then
            echo "Current profile: $profile_name (symlink)"
          else
            echo "Current profile: custom (symlink to $target)"
          fi
          return
        fi

        if [ -f "$CONFIG_FILE" ]; then
          echo "Current profile: custom (plain file, not symlinked)"
          return
        fi

        echo "Current profile: unset"
      }

      switch_profile() {
        local profile_name
        profile_name="$1"

        if ! profile_exists "$profile_name"; then
          echo "Error: profile '$profile_name' not found." >&2
          echo "Use 'opencode-profile list' to see available profiles." >&2
          exit 1
        fi

        ensure_profile_file "$profile_name"
        ln -sfn "$PROFILES_DIR/$profile_name.json" "$CONFIG_FILE"

        echo "Switched opencode profile to '$profile_name'."
      }

      command="''${1:-}"
      case "$command" in
        list)
          list_profiles
          ;;
        show)
          show_current_profile
          ;;
        switch)
          if [ $# -ne 2 ]; then
            echo "Error: switch requires exactly one profile name." >&2
            usage
            exit 1
          fi
          switch_profile "$2"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
  };
in {
  options.custom.opencode.profile = lib.mkOption {
    type = lib.types.enum profileNames;
    default = defaultProfile;
    description = ''
      Agent model profile for oh-my-opencode.
    '';
  };

  config = {
    home.packages = [opencodeProfile];

    # Generate one immutable profile file per model profile.
    xdg.configFile = profileConfigFiles;

    # Seed active profile symlink if missing.
    # This path stays runtime-managed so profile switches do not fight Home Manager.
    home.activation.bootstrapOhMyOpencodeConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      OPENCODE_DIR="${config.xdg.configHome}/opencode"
      OPENCODE_CONFIG="$OPENCODE_DIR/oh-my-opencode.json"
      OPENCODE_DEFAULT_PROFILE="$OPENCODE_DIR/profiles/${cfg.profile}.json"

      mkdir -p "$OPENCODE_DIR"

      if [ ! -L "$OPENCODE_CONFIG" ] && [ ! -f "$OPENCODE_CONFIG" ]; then
        ln -s "$OPENCODE_DEFAULT_PROFILE" "$OPENCODE_CONFIG"
      fi
    '';
  };
}
