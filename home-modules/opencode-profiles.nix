{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.opencode;
  defaultProfile = "balanced";

  # ── Profile & mode metadata ───────────────────────────────────────────
  baseProfileDescriptions = {
    balanced = "Everyday default";
    cheap = "Lower-cost / high-volume";
    max = "Best quality";
    visual = "UI / screenshots / multimodal";
    "go-balanced" = "OpenCode Go native models";
  };

  modeDescriptions = {
    subscriptions = "Direct provider subs first (requires all auth)";
    mixed = "Copilot for Claude + direct OpenAI/Google";
    go = "OpenCode Go subscription first";
    "go-tokens" = "OpenCode Go token-based (pay per use)";
    overflow = "Copilot-first fallback rails";
    zen = "OpenCode only / pay-per-token";
  };

  # ── Agent assignments per base profile ────────────────────────────────
  # Each entry is either:
  #   "aliasName"                                → resolves to { model }
  #   { alias = "aliasName"; variant = "high"; } → resolves to { model, variant }
  baseAgents = {
    balanced = {
      sisyphus = "claudeMax";
      prometheus = "claudeMax";
      build = "codexMax";
      plan = {alias = "reasoningStrong"; variant = "high";};
      "OpenCode-Builder" = "codexMax";
      "sisyphus-junior" = "claudeBalanced";
      oracle = {alias = "reasoningStrong"; variant = "high";};
      metis = "claudeMax";
      momus = {alias = "reasoningStrong"; variant = "xhigh";};
      atlas = "claudeBalanced";
      librarian = "speedUtility";
      explore = "speedUtility";
      "multimodal-looker" = "reasoningStrong";
    };
    cheap = {
      sisyphus = "claudeBalanced";
      prometheus = "claudeBalanced";
      build = "codexCheap";
      plan = "reasoningCheap";
      "OpenCode-Builder" = "codexCheap";
      "sisyphus-junior" = "claudeHaiku";
      oracle = "reasoningCheap";
      metis = "claudeBalanced";
      momus = "reasoningCheap";
      atlas = "claudeHaiku";
      librarian = "speedUtility";
      explore = "speedUtility";
      "multimodal-looker" = "kimiBalanced";
    };
    max = {
      sisyphus = "claudeMax";
      prometheus = "claudeMax";
      build = "codexMax";
      plan = {alias = "reasoningStrong"; variant = "xhigh";};
      "OpenCode-Builder" = "codexMax";
      "sisyphus-junior" = "claudeBalanced";
      oracle = {alias = "reasoningStrong"; variant = "high";};
      metis = "claudeMax";
      momus = {alias = "reasoningStrong"; variant = "xhigh";};
      atlas = "claudeBalanced";
      librarian = "claudeBalanced";
      explore = "claudeBalanced";
      "multimodal-looker" = {alias = "reasoningStrong"; variant = "high";};
    };
    visual = {
      sisyphus = "claudeMax";
      prometheus = "claudeMax";
      build = "codexMax";
      plan = {alias = "reasoningStrong"; variant = "high";};
      "OpenCode-Builder" = "codexMax";
      "sisyphus-junior" = "claudeBalanced";
      oracle = {alias = "reasoningStrong"; variant = "high";};
      metis = "claudeMax";
      momus = {alias = "reasoningStrong"; variant = "xhigh";};
      atlas = "claudeBalanced";
      librarian = "speedUtility";
      explore = "speedUtility";
      "multimodal-looker" = "visualBalanced";
    };
    # Go-native: Kimi K2.5 for orchestration, GLM-5 for reasoning, MiniMax for utility
    "go-balanced" = {
      sisyphus = "kimiBalanced";
      prometheus = "glmBalanced";
      build = "codexMax"; # No Go equivalent for Codex
      plan = "glmBalanced";
      "OpenCode-Builder" = "codexMax";
      "sisyphus-junior" = "kimiBalanced";
      oracle = "glmBalanced";
      metis = "glmBalanced";
      momus = "glmBalanced";
      atlas = "kimiBalanced";
      librarian = "speedUtility"; # MiniMax M2.5
      explore = "speedUtility"; # MiniMax M2.5
      "multimodal-looker" = "kimiBalanced"; # Only Go model with vision
    };
  };

  # ── Category assignments per base profile ─────────────────────────────
  baseCategories = {
    balanced = {
      "visual-engineering" = {alias = "visualBalanced"; variant = "high";};
      ultrabrain = {alias = "reasoningStrong"; variant = "xhigh";};
      deep = "codexMax";
      artistry = "visualBalanced";
      quick = "gptMini";
      "unspecified-high" = {alias = "claudeMax"; variant = "max";};
      "unspecified-low" = "claudeBalanced";
      writing = "flashBalanced";
    };
    cheap = {
      "visual-engineering" = "visualBalanced";
      ultrabrain = "reasoningCheap";
      deep = "codexCheap";
      artistry = "visualBalanced";
      quick = "gptNano";
      "unspecified-high" = "claudeBalanced";
      "unspecified-low" = "claudeHaiku";
      writing = "flashBalanced";
    };
    max = {
      "visual-engineering" = {alias = "visualBalanced"; variant = "high";};
      ultrabrain = {alias = "reasoningStrong"; variant = "xhigh";};
      deep = "codexMax";
      artistry = {alias = "visualBalanced"; variant = "high";};
      quick = "gptMini";
      "unspecified-high" = {alias = "claudeMax"; variant = "max";};
      "unspecified-low" = "claudeMax";
      writing = "claudeBalanced";
    };
    visual = {
      "visual-engineering" = {alias = "visualBalanced"; variant = "high";};
      ultrabrain = {alias = "reasoningStrong"; variant = "xhigh";};
      deep = "codexMax";
      artistry = {alias = "visualBalanced"; variant = "high";};
      quick = "gptMini";
      "unspecified-high" = {alias = "claudeMax"; variant = "max";};
      "unspecified-low" = "claudeBalanced";
      writing = "flashBalanced";
    };
    "go-balanced" = {
      "visual-engineering" = "kimiBalanced"; # Kimi — multimodal vision-to-code
      ultrabrain = "glmBalanced"; # GLM-5 — strong reasoning
      deep = "minimaxFast"; # M2.7 — matches Opus on SWE-Pro
      artistry = "kimiBalanced"; # Kimi — creative multimodal
      quick = "minimaxFast"; # M2.7 — fast and smart
      "unspecified-high" = "glmBalanced"; # GLM-5
      "unspecified-low" = "speedUtility"; # M2.5 — cheapest
      writing = "glmCheap"; # GLM-5 turbo
    };
  };

  # ── Provider priority per mode × family ───────────────────────────────
  providerModes = {
    subscriptions = {
      claude = ["anthropic" "copilot" "opencode"];
      gpt = ["openai" "copilot" "opencode"];
      gemini = ["google" "opencode"];
      glm = ["zhipu" "opencode"];
      kimi = ["opencode"];
      speed = ["copilot" "opencode"];
    };
    mixed = {
      claude = ["copilot" "opencode"];
      gpt = ["openai" "copilot" "opencode"];
      gemini = ["google" "opencode"];
      glm = ["zhipu" "opencode"];
      kimi = ["opencode"];
      speed = ["copilot" "opencode"];
    };
    go = {
      # OpenCode Go subscription first for models available in Go tier
      # Go tier has: GLM-5, Kimi K2.5, MiniMax M2.5/M2.7
      # Other models fall back to regular OpenCode (Zen)
      claude = ["opencode" "copilot"];
      gpt = ["opencode" "copilot" "openai"];
      gemini = ["opencode" "google"];
      glm = ["opencode-go" "opencode" "zhipu"];
      kimi = ["opencode-go" "opencode"];
      speed = ["opencode-go" "opencode" "copilot"];
    };
    "go-tokens" = {
      # OpenCode Go tier only has GLM, Kimi, and MiniMax models
      # Claude, GPT, Gemini are NOT available in Go tier (use zen mode for those)
      claude = ["opencode" "copilot" "anthropic"];
      gpt = ["opencode" "copilot" "openai"];
      gemini = ["opencode" "google"];
      glm = ["opencode-go" "opencode" "zhipu"];
      kimi = ["opencode-go" "opencode"];
      speed = ["opencode-go" "opencode" "copilot"];
    };
    overflow = {
      claude = ["copilot" "opencode" "anthropic"];
      gpt = ["copilot" "opencode" "openai"];
      gemini = ["opencode" "google"];
      glm = ["opencode" "zhipu"];
      kimi = ["opencode"];
      speed = ["copilot" "opencode"];
    };
    zen = {
      claude = ["opencode"];
      gpt = ["opencode"];
      gemini = ["opencode"];
      glm = ["opencode"];
      kimi = ["opencode"];
      speed = ["opencode"];
    };
  };

  # ── Model aliases ─────────────────────────────────────────────────────
  modelAliases = {
    # Claude family — OpenCode Go tier does NOT have Claude models
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
    claudeHaiku = {
      family = "claude";
      providers = {
        anthropic = "anthropic/claude-haiku-4-5";
        copilot = "github-copilot/claude-haiku-4.5";
        opencode = "opencode/claude-haiku-4-5";
      };
    };

    # GPT / Codex family — OpenCode Go tier does NOT have GPT models
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
        openai = "openai/gpt-5.4";
        copilot = "github-copilot/gpt-5.4";
        opencode = "opencode/gpt-5.4-pro";
      };
    };
    gptMini = {
      family = "gpt";
      providers = {
        copilot = "github-copilot/gpt-5.4-mini";
        opencode = "opencode/gpt-5.4-mini";
      };
    };
    gptNano = {
      family = "gpt";
      providers = {
        opencode = "opencode/gpt-5-nano";
      };
    };

    # Gemini family — OpenCode Go tier does NOT have Gemini models
    reasoningCheap = {
      family = "gemini";
      providers = {
        google = "google/gemini-3.1-pro-preview";
        opencode = "opencode/gemini-3.1-pro";
      };
    };
    flashBalanced = {
      family = "gemini";
      providers = {
        google = "google/gemini-3-flash-preview";
        opencode = "opencode/gemini-3-flash";
      };
    };
    visualBalanced = {
      family = "gemini";
      providers = {
        google = "google/gemini-3.1-pro-preview";
        opencode = "opencode/gemini-3.1-pro";
      };
    };

    # Speed family — MiniMax models available in OpenCode Go tier
    speedUtility = {
      family = "speed";
      providers = {
        copilot = "github-copilot/grok-code-fast-1";
        opencode = "opencode/minimax-m2.5";
        "opencode-go" = "opencode-go/minimax-m2.5";
      };
    };

    # GLM family — GLM-5 available in OpenCode Go tier
    glmBalanced = {
      family = "glm";
      providers = {
        zhipu = "zhipuai-coding-plan/glm-5";
        opencode = "opencode/glm-5";
        "opencode-go" = "opencode-go/glm-5";
      };
    };
    glmCheap = {
      family = "glm";
      providers = {
        zhipu = "zhipuai-coding-plan/glm-5-turbo";
        opencode = "opencode/glm-5";
        "opencode-go" = "opencode-go/glm-5";
      };
    };

    # Kimi family — Kimi K2.5 available in OpenCode Go tier
    kimiBalanced = {
      family = "kimi";
      providers = {
        opencode = "opencode/kimi-k2.5";
        "opencode-go" = "opencode-go/kimi-k2.5";
      };
    };

    # MiniMax family — MiniMax M2.7 available in OpenCode Go tier
    minimaxFast = {
      family = "speed";
      providers = {
        opencode = "opencode/minimax-m2.7";
        "opencode-go" = "opencode-go/minimax-m2.7";
      };
    };
  };

  # ── Static agent extras (applied to all profiles/modes) ─────────────
  noLongRunningProcesses = ''
    PROCESS EXECUTION RULE: Never start long-lived or background processes (servers, watchers, docker-compose up, nix-build with --keep-going, dev servers, etc.) directly. Instead, output the exact command so the user can run it in their own tmux session. Short-lived commands that complete quickly (tests, linters, single builds, git operations) are fine to run directly.'';

  agentExtras = let
    shared = {
      prompt_append = noLongRunningProcesses;
      permission = {
        bash = {
          git = "ask";
        };
      };
    };
  in {
    sisyphus = shared;
    "sisyphus-junior" = shared;
    build = shared;
    "OpenCode-Builder" = shared;
  };

  # ── Resolution engine ─────────────────────────────────────────────────

  # Resolve a model alias to a concrete provider/model string.
  resolveAlias = providerOrder: aliasName:
    let
      alias = modelAliases.${aliasName};
      family = alias.family;
      candidates = builtins.filter (p: builtins.hasAttr p alias.providers) providerOrder.${family};
    in
      if candidates == []
      then throw "No provider found for alias ${aliasName} in family ${family}"
      else alias.providers.${builtins.head candidates};

  # Resolve a profile entry (string or { alias, variant? }) to { model, variant? }.
  resolveEntry = providerOrder: entry:
    let
      aliasName =
        if builtins.isString entry
        then entry
        else entry.alias;
      model = resolveAlias providerOrder aliasName;
    in
      {inherit model;}
      // (
        if builtins.isAttrs entry && entry ? variant
        then {inherit (entry) variant;}
        else {}
      );

  # Resolve every base profile × mode into concrete { agents, categories }.
  resolvedProfiles = lib.foldl' (
    acc: modeName: let
      mode = providerModes.${modeName};

      resolveSection = section:
        lib.mapAttrs (
          _baseName: entries:
            lib.mapAttrs (_entryName: resolveEntry mode) entries
        )
        section;

      modeAgents = resolveSection baseAgents;
      modeCategories = resolveSection baseCategories;

      modeNamePrefix =
        if modeName == "subscriptions"
        then ""
        else "-${modeName}";

      namespacedSettings = lib.mapAttrs' (
        baseName: agents:
          lib.nameValuePair "${baseName}${modeNamePrefix}" {
            inherit agents;
            categories = modeCategories.${baseName};
          }
      ) modeAgents;
    in
      acc // namespacedSettings
  ) {} (builtins.attrNames providerModes);

  profileNames = builtins.attrNames resolvedProfiles;

  mkOhMyOpencodeSettings = {
    agents,
    categories,
  }: {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    google_auth = false;
    agents = lib.mapAttrs (name: settings:
      settings // (agentExtras.${name} or {})
    ) agents;
    inherit categories;
    git_master = {
      commit_footer = false;
      include_co_authored_by = false;
    };
  };

  # CLI data
  profileManifest = {
    inherit baseAgents baseCategories providerModes baseProfileDescriptions modeDescriptions;
    inherit resolvedProfiles;
  };

  profileConfigFiles =
    lib.mapAttrs' (
      profileName: settings:
        lib.nameValuePair "opencode/profiles/${profileName}.json" {
          text = builtins.toJSON (mkOhMyOpencodeSettings settings);
        }
    )
    resolvedProfiles
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
      BASE_PROFILES='${builtins.toJSON (builtins.attrNames baseAgents)}'
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
           echo -e "\nAgent                       Model                                    Variant"
           echo "─────────────────────────── ──────────────────────────────────────── ───────"
           jq -r '.agents | to_entries | sort_by(.key) | .[] | "\(.key)\t\(.value.model)\t\(.value.variant // "-")"' "$config_path" | while IFS=$'\t' read -r name model variant; do
             printf "%-27s %-40s %s\n" "$name" "$model" "$variant"
           done

           if jq -e '.categories' "$config_path" >/dev/null 2>&1; then
             echo -e "\nCategory                    Model                                    Variant"
             echo "─────────────────────────── ──────────────────────────────────────── ───────"
             jq -r '.categories | to_entries | sort_by(.key) | .[] | "\(.key)\t\(.value.model)\t\(.value.variant // "-")"' "$config_path" | while IFS=$'\t' read -r name model variant; do
               printf "%-27s %-40s %s\n" "$name" "$model" "$variant"
             done
           fi
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
