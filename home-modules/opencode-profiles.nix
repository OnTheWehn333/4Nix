{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.opencode;
  defaultProfile = "balanced";

  # Shared defaults for all profiles — only sisyphus/prometheus change per profile.
  # Every oh-my-opencode agent is listed explicitly to prevent fallback to anthropic.
  # Tier logic: heavy reasoning → gemini-3.1-pro, lightweight/utility → flash-lite.
  baseProfileDescriptions = {
    balanced = "Everyday default";
    cheap = "Lower-cost / high-volume";
    max = "Best quality";
    visual = "UI / screenshots / multimodal";
  };

  modeDescriptions = {
    subscriptions = "Use subscriptions first";
    overflow = "Use fallback rails when limited";
    zen = "Force Zen / pay-per-token";
  };

  baseProfiles = {
    balanced = {
      sisyphus = "claudeMax";
      prometheus = "claudeMax";
      hephaestus = "claudeMax";
      oracle = "reasoningStrong";
      metis = "reasoningStrong";
      momus = "reasoningStrong";
      atlas = "reasoningStrong";
      librarian = "flashBalanced";
      explore = "flashBalanced";
      "document-writer" = "flashBalanced";
      "multimodal-looker" = "flashBalanced";
      "frontend-ui-ux-engineer" = "claudeMax";
    };
    cheap = {
      sisyphus = "claudeBalanced";
      prometheus = "claudeBalanced";
      hephaestus = "claudeBalanced";
      oracle = "reasoningCheap";
      metis = "reasoningCheap";
      momus = "reasoningCheap";
      atlas = "reasoningCheap";
      librarian = "flashBalanced";
      explore = "flashBalanced";
      "document-writer" = "flashBalanced";
      "multimodal-looker" = "flashBalanced";
      "frontend-ui-ux-engineer" = "claudeBalanced";
    };
    max = {
      sisyphus = "claudeMax";
      prometheus = "claudeMax";
      hephaestus = "codexMax";
      oracle = "reasoningStrong";
      metis = "reasoningStrong";
      momus = "reasoningStrong";
      atlas = "reasoningStrong";
      librarian = "claudeBalanced";
      explore = "claudeBalanced";
      "document-writer" = "claudeBalanced";
      "multimodal-looker" = "visualBalanced";
      "frontend-ui-ux-engineer" = "claudeMax";
    };
    visual = {
      sisyphus = "visualBalanced";
      prometheus = "visualBalanced";
      hephaestus = "visualBalanced";
      oracle = "reasoningStrong";
      metis = "reasoningStrong";
      momus = "reasoningStrong";
      atlas = "reasoningStrong";
      librarian = "flashBalanced";
      explore = "flashBalanced";
      "document-writer" = "flashBalanced";
      "multimodal-looker" = "visualBalanced";
      "frontend-ui-ux-engineer" = "visualBalanced";
    };
  };

  providerModes = {
    subscriptions = {
      claude = ["anthropic" "copilot" "opencode"];
      gpt = ["openai" "copilot" "opencode"];
      gemini = ["google" "opencode"];
      glm = ["zhipu" "opencode"];
      kimi = ["moonshot" "opencode"];
    };
    overflow = {
      claude = ["copilot" "opencode" "anthropic"];
      gpt = ["copilot" "opencode" "openai"];
      gemini = ["opencode" "google"];
      glm = ["opencode" "zhipu"];
      kimi = ["opencode" "moonshot"];
    };
    zen = {
      claude = ["opencode"];
      gpt = ["opencode"];
      gemini = ["opencode"];
      glm = ["opencode"];
      kimi = ["opencode"];
    };
  };

  modelAliases = {
    claudeMax = {
      family = "claude";
      providers = {
        anthropic = "anthropic/claude-opus-4-6";
        copilot = "github-copilot/claude-opus-4.6";
        opencode = "opencode/claude-opus-4-6";
      };
    };
    claudeBalanced = {
      family = "claude";
      providers = {
        anthropic = "anthropic/claude-sonnet-4-6";
        copilot = "github-copilot/claude-sonnet-4.6";
        opencode = "opencode/claude-sonnet-4-6";
      };
    };
    codexMax = {
      family = "gpt";
      providers = {
        openai = "openai/gpt-5.3-codex";
        copilot = "github-copilot/gpt-5.3-codex";
        opencode = "opencode/gpt-5.3-codex";
      };
    };
    codexBalanced = {
      family = "gpt";
      providers = {
        openai = "openai/gpt-5.2-codex";
        copilot = "github-copilot/gpt-5.2-codex";
        opencode = "opencode/gpt-5.2-codex";
      };
    };
    codexCheap = {
      family = "gpt";
      providers = {
        openai = "openai/gpt-5.1-codex";
        copilot = "github-copilot/gpt-5.1-codex";
        opencode = "opencode/gpt-5.1-codex";
      };
    };
    reasoningStrong = {
      family = "gpt";
      providers = {
        openai = "openai/gpt-5.4-reasoning";
        copilot = "github-copilot/gpt-5.4-reasoning";
        opencode = "opencode/gpt-5.4-reasoning";
      };
    };
    reasoningCheap = {
      family = "gemini";
      providers = {
        google = "google/gemini-3.1-pro";
        opencode = "opencode/gemini-3.1-pro";
      };
    };
    flashBalanced = {
      family = "gemini";
      providers = {
        google = "google/antigravity-gemini-3-flash";
        opencode = "opencode/antigravity-gemini-3-flash";
      };
    };
    visualBalanced = {
      family = "gemini";
      providers = {
        google = "google/gemini-3.1-pro-vision";
        opencode = "opencode/gemini-3.1-pro-vision";
      };
    };
    glmBalanced = {
      family = "glm";
      providers = {
        zhipu = "zhipuai-coding-plan/glm-5";
        opencode = "opencode/glm-5";
      };
    };
    glmCheap = {
      family = "glm";
      providers = {
        zhipu = "zhipuai-coding-plan/glm-5-flash";
        opencode = "opencode/glm-5-flash";
      };
    };
    kimiBalanced = {
      family = "kimi";
      providers = {
        moonshot = "moonshot/kimi-2.5-pro";
        opencode = "opencode/kimi-2.5-pro";
      };
    };
  };

  resolveAlias = providerOrder: aliasName:
    let
      alias = modelAliases.${aliasName};
      family = alias.family;
      # Find the first provider in family order that exists in alias.providers
      candidates = builtins.filter (p: builtins.hasAttr p alias.providers) providerOrder.${family};
    in
      if candidates == []
      then throw "No provider found for alias ${aliasName} in family ${family}"
      else alias.providers.${builtins.head candidates};

  resolvedProfiles = lib.foldl' (acc: modeName:
    let
      mode = providerModes.${modeName};
      modeProfiles = lib.mapAttrs (baseName: agents:
        lib.mapAttrs (_: aliasName: resolveAlias mode aliasName) agents
      ) baseProfiles;
      
      # Prefix profile name for non-subscription modes
      modeNamePrefix = if modeName == "subscriptions" then "" else "-${modeName}";
      
      namespacedProfiles = lib.mapAttrs' (baseName: agents:
        lib.nameValuePair "${baseName}${modeNamePrefix}" agents
      ) modeProfiles;
    in
      acc // namespacedProfiles
  ) {} (builtins.attrNames providerModes);

  profileAgentSettings = lib.mapAttrs (_: agents: lib.mapAttrs (_: model: {inherit model;}) agents) resolvedProfiles;
  profileNames = builtins.attrNames resolvedProfiles;

  mkOhMyOpencodeSettings = agents: {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    google_auth = false;
    agents = agents;
  };

  # CLI data
  profileManifest = {
    inherit baseProfiles providerModes baseProfileDescriptions modeDescriptions;
    resolvedProfiles = profileAgentSettings;
  };

  profileConfigFiles =
    lib.mapAttrs' (
      profileName: agents:
        lib.nameValuePair "opencode/profiles/${profileName}.json" {
          text = builtins.toJSON (mkOhMyOpencodeSettings agents);
        }
    )
    profileAgentSettings
    // {
        "opencode/profile-manifest.json" = {
          text = builtins.toJSON profileManifest;
        };
      };

  opencodeProfile = pkgs.writeShellApplication {
    name = "opencode-profile";
    runtimeInputs = [pkgs.jq pkgs.coreutils];
    text = ''
      set -euo pipefail

      CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      CONFIG_FILE="$CONFIG_HOME/opencode/oh-my-opencode.json"
      PROFILES_DIR="$CONFIG_HOME/opencode/profiles"

      BUILTIN_PROFILES='${builtins.toJSON profileNames}'
      BASE_PROFILES='${builtins.toJSON (builtins.attrNames baseProfiles)}'
      MODES='${builtins.toJSON (builtins.attrNames providerModes)}'
      BASE_DESCRIPTIONS='${builtins.toJSON baseProfileDescriptions}'
      MODE_DESCRIPTIONS='${builtins.toJSON modeDescriptions}'

      usage() {
        cat <<'EOF'
      Usage:
        opencode-profile list
        opencode-profile show [--project]
        opencode-profile switch <profile> [--project]
        opencode-profile pick [--project]
      EOF
      }

      get_effective_scope() {
        local project_flag="${"$"}{1:-}"
        if [ "$project_flag" = "--project" ]; then
          echo "project"
        else
          echo "user"
        fi
      }

      list_profiles() {
        echo "Base profiles:"
        jq -r 'to_entries | .[] | "  - \(.key): \(.value)"' <<<"$BASE_DESCRIPTIONS"
        echo -e "\nModes:"
        jq -r 'to_entries | .[] | "  - \(.key): \(.value)"' <<<"$MODE_DESCRIPTIONS"
        echo -e "\nAvailable combinations:"
        jq -r '.[] | "  - " + .' <<<"$BUILTIN_PROFILES"
      }

      show_current() {
        local project_flag="${"$"}{1:-}"
        local scope="user"
        local config_path="$CONFIG_FILE"
        local override="none"
        
        if [ "$project_flag" = "--project" ]; then
          scope="project"
          config_path=".opencode/oh-my-opencode.json"
        fi

        if [ -f ".opencode/oh-my-opencode.json" ]; then
          override="$(jq -r '.profile // "custom"' .opencode/oh-my-opencode.json 2>/dev/null || echo "custom")"
        fi
        
        local effective="unset"
        if [ -L "$CONFIG_FILE" ]; then
            effective="$(basename "$(readlink "$CONFIG_FILE" 2>/dev/null || echo "none")" .json)"
        fi
        if [ -f ".opencode/oh-my-opencode.json" ]; then
            effective="$override"
            config_path=".opencode/oh-my-opencode.json"
        fi

        echo "User default:    $(basename "$(readlink "$CONFIG_FILE" 2>/dev/null || echo "none")" .json)"
        echo "Project override: $override $( [ -f ".opencode/oh-my-opencode.json" ] && echo "(via .opencode/oh-my-opencode.json)" )"
        echo "Effective:       $effective"
        
        if [ -f "$config_path" ]; then
           echo -e "\nAgent                       Model"
           echo "─────────────────────────── ────────────────────────────────────"
           jq -r '.agents | to_entries | .[] | "\(.key)\t\(.value.model)"' "$config_path" | while IFS=$'\t' read -r agent model; do
             printf "%-27s %s\n" "$agent" "$model"
           done
        else
           echo "Status: Config not found."
        fi
      }

      pick_profile() {
        local project_flag="${"$"}{1:-}"
        
        echo "Select Base Profile:"
        local base_names
        base_names=$(jq -r '.[]' <<<"$BASE_PROFILES")
        local i=1
        local base_arr=()
        while read -r name; do
           printf "%d) %s: %s\n" "$i" "$name" "$(jq -r --arg k "$name" '.[$k]' <<<"$BASE_DESCRIPTIONS")"
           base_arr+=("$name")
           ((i++))
        done <<< "$base_names"
        
        read -r -p "Choose base (1-$((i-1))): " choice
        local base=''${base_arr[$((choice-1))]}
        
        echo -e "\nSelect Mode:"
        local mode_names
        mode_names=$(jq -r '.[]' <<<"$MODES")
        i=1
        local mode_arr=()
        while read -r name; do
           printf "%d) %s: %s\n" "$i" "$name" "$(jq -r --arg k "$name" '.[$k]' <<<"$MODE_DESCRIPTIONS")"
           mode_arr+=("$name")
           ((i++))
        done <<< "$mode_names"
        
        read -r -p "Choose mode (1-$((i-1))): " choice
        local mode=''${mode_arr[$((choice-1))]}
        
        local p="$base"
        [ "$mode" != "subscriptions" ] && p="$base-$mode"
        switch_profile "$p" "$project_flag"
      }


      switch_profile() {
        local profile_name="$1"
        local scope
        scope="$(get_effective_scope "${"$"}{2:-}")"
        
        if ! jq -e --arg p "$profile_name" '. | index($p)' <<<"$BUILTIN_PROFILES" >/dev/null; then
           echo "Error: profile '$profile_name' not found." >&2
           exit 1
        fi

        if [ "$scope" = "project" ]; then
          if [ ! -d ".git" ] && [ ! -d ".opencode" ]; then
             echo "Error: Not in a project directory (no .git or .opencode found)." >&2
             exit 1
          fi
          mkdir -p .opencode
          jq '.' "$PROFILES_DIR/$profile_name.json" > ".opencode/oh-my-opencode.json"
          echo "Switched to project profile '$profile_name'."
        else
          ln -sfn "$PROFILES_DIR/$profile_name.json" "$CONFIG_FILE"
          echo "Switched to user profile '$profile_name'."
        fi
      }

      command="''${1:-}"
      shift || true
      case "$command" in
        list) list_profiles ;;
        show) show_current "$@" ;;
        switch) 
           p="$1"; shift
           switch_profile "$p" "$@"
           ;;
        pick)
           pick_profile "$@"
           ;;
        *) usage; exit 1 ;;
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
