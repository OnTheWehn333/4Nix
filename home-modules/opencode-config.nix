{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.opencode;

  # ── Safety prompt for long-running processes ──────────────────────────────
  noLongRunningProcesses = ''
    PROCESS EXECUTION RULE: Never start long-lived or background processes (servers, watchers, docker-compose up, nix-build with --keep-going, dev servers, etc.) directly. Instead, output the exact command so the user can run it in their own tmux session. Short-lived commands that complete quickly (tests, linters, single builds, git operations) are fine to run directly.'';

  # ── Agent extras ──────────────────────────────────────────────────────────
  agentExtras = {
    sisyphus = {
      prompt_append = noLongRunningProcesses;
      permission.bash.git = "ask";
    };
    sisyphus-junior = {
      prompt_append = noLongRunningProcesses;
      permission.bash.git = "ask";
    };
    build = {
      prompt_append = noLongRunningProcesses;
      permission.bash.git = "ask";
    };
    OpenCode-Builder = {
      prompt_append = noLongRunningProcesses;
      permission.bash.git = "ask";
    };
  };

  # ── Static config fields ──────────────────────────────────────────────────
  staticConfig = {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    google_auth = false;
    git_master = {
      commit_footer = false;
      include_co_authored_by = false;
    };
  };

  # ── Provider names (for interactive UI) ───────────────────────────────────
  providerNames = {
    copilot = "GitHub Copilot (subscription)";
    openai = "OpenAI (direct OAuth)";
    google = "Google (Antigravity)";
    "opencode-go" = "OpenCode Go (flat-rate)";
    opencode = "OpenCode Zen (pay-per-token)";
  };

  # ── Default provider priority ──────────────────────────────────────────────
  defaultProviderPriority = ["copilot" "openai" "google" "opencode-go" "opencode"];

  # ── Model catalog ─────────────────────────────────────────────────────────
  modelCatalog = {
    claude-opus = {
      providers = {
        copilot = "github-copilot/claude-opus-4.6";
        opencode = "opencode/claude-opus-4-6";
      };
    };
    claude-sonnet = {
      providers = {
        copilot = "github-copilot/claude-sonnet-4.6";
        opencode = "opencode/claude-sonnet-4-6";
      };
    };
    claude-haiku = {
      providers = {
        copilot = "github-copilot/claude-haiku-4.5";
        opencode = "opencode/claude-haiku-4-5";
      };
    };
    gpt-5-4 = {
      providers = {
        openai = "openai/gpt-5.4";
        copilot = "github-copilot/gpt-5.4";
        opencode = "opencode/gpt-5.4-pro";
      };
    };
    gpt-5-4-mini = {
      providers = {
        copilot = "github-copilot/gpt-5.4-mini";
        opencode = "opencode/gpt-5.4-mini";
      };
    };
    gpt-5-nano = {
      providers = {
        opencode = "opencode/gpt-5-nano";
      };
    };
    codex-5-3 = {
      providers = {
        openai = "openai/gpt-5.3-codex";
        copilot = "github-copilot/gpt-5.3-codex";
        opencode = "opencode/gpt-5.3-codex";
      };
    };
    codex-5-2 = {
      providers = {
        openai = "openai/gpt-5.2-codex";
        copilot = "github-copilot/gpt-5.2-codex";
        opencode = "opencode/gpt-5.2-codex";
      };
    };
    codex-5-1 = {
      providers = {
        openai = "openai/gpt-5.1-codex";
        copilot = "github-copilot/gpt-5.1-codex";
        opencode = "opencode/gpt-5.1-codex";
      };
    };
    gemini-3-1-pro = {
      providers = {
        google = "google/gemini-3.1-pro-preview";
        opencode = "opencode/gemini-3.1-pro";
      };
    };
    gemini-3-flash = {
      providers = {
        google = "google/gemini-3-flash-preview";
        opencode = "opencode/gemini-3-flash";
      };
    };
    glm-5 = {
      providers = {
        "opencode-go" = "opencode-go/glm-5";
        opencode = "opencode/glm-5";
      };
    };
    kimi-k2-5 = {
      providers = {
        "opencode-go" = "opencode-go/kimi-k2.5";
        opencode = "opencode/kimi-k2.5";
      };
    };
    minimax-m2-5 = {
      providers = {
        "opencode-go" = "opencode-go/minimax-m2.5";
        opencode = "opencode/minimax-m2.5";
      };
    };
    minimax-m2-7 = {
      providers = {
        "opencode-go" = "opencode-go/minimax-m2.7";
        opencode = "opencode/minimax-m2.7";
      };
    };
    grok-code-fast = {
      providers = {
        copilot = "github-copilot/grok-code-fast-1";
      };
    };
    antigravity-pro-high = {
      providers = {
        google = "google/antigravity-gemini-3-pro-high";
      };
    };
    antigravity-pro-low = {
      providers = {
        google = "google/antigravity-gemini-3-pro-low";
      };
    };
    antigravity-flash = {
      providers = {
        google = "google/antigravity-gemini-3-flash";
      };
    };
  };

  # ── Tier assignments ──────────────────────────────────────────────────────
  tierAssignments = {
    balanced = {
      agents = {
        sisyphus = "claude-opus";
        prometheus = "claude-opus";
        oracle = {
          model = "gpt-5-4";
          variant = "high";
        };
        metis = "claude-opus";
        momus = {
          model = "gpt-5-4";
          variant = "xhigh";
        };
        librarian = "grok-code-fast";
        explore = "grok-code-fast";
        multimodal-looker = {
          model = "gpt-5-4";
          variant = "medium";
        };
        atlas = "claude-sonnet";
        sisyphus-junior = "claude-sonnet";
        build = "codex-5-3";
        plan = {
          model = "gpt-5-4";
          variant = "high";
        };
        OpenCode-Builder = "codex-5-3";
      };
      categories = {
        visual-engineering = {
          model = "gemini-3-1-pro";
          variant = "high";
        };
        ultrabrain = {
          model = "gpt-5-4";
          variant = "xhigh";
        };
        deep = "codex-5-3";
        artistry = "gemini-3-1-pro";
        quick = "gpt-5-4-mini";
        unspecified-high = {
          model = "claude-opus";
          variant = "max";
        };
        unspecified-low = "claude-sonnet";
        writing = "gemini-3-flash";
      };
    };

    max = {
      agents = {
        sisyphus = "claude-opus";
        prometheus = "claude-opus";
        oracle = {
          model = "gpt-5-4";
          variant = "xhigh";
        };
        metis = "claude-opus";
        momus = {
          model = "gpt-5-4";
          variant = "xhigh";
        };
        librarian = "claude-opus";
        explore = "claude-opus";
        multimodal-looker = {
          model = "gpt-5-4";
          variant = "high";
        };
        atlas = "claude-opus";
        sisyphus-junior = "claude-opus";
        build = "codex-5-3";
        plan = {
          model = "gpt-5-4";
          variant = "xhigh";
        };
        OpenCode-Builder = "codex-5-3";
      };
      categories = {
        visual-engineering = {
          model = "antigravity-pro-high";
          variant = "high";
        };
        ultrabrain = {
          model = "gpt-5-4";
          variant = "xhigh";
        };
        deep = "codex-5-3";
        artistry = {
          model = "gemini-3-1-pro";
          variant = "high";
        };
        quick = "gpt-5-4-mini";
        unspecified-high = {
          model = "claude-opus";
          variant = "max";
        };
        unspecified-low = "claude-opus";
        writing = "claude-sonnet";
      };
    };

    budget = {
      agents = {
        sisyphus = "kimi-k2-5";
        prometheus = "glm-5";
        oracle = "glm-5";
        metis = "glm-5";
        momus = "glm-5";
        librarian = "minimax-m2-5";
        explore = "minimax-m2-5";
        multimodal-looker = "kimi-k2-5";
        atlas = "minimax-m2-5";
        sisyphus-junior = "minimax-m2-7";
        build = "minimax-m2-7";
        plan = "glm-5";
        OpenCode-Builder = "minimax-m2-7";
      };
      categories = {
        visual-engineering = "kimi-k2-5";
        ultrabrain = "glm-5";
        deep = "minimax-m2-7";
        artistry = "kimi-k2-5";
        quick = "minimax-m2-5";
        unspecified-high = "glm-5";
        unspecified-low = "minimax-m2-5";
        writing = "minimax-m2-5";
      };
    };
  };

  # ── Resolution engine (Nix-side, for seeding default config) ──────────────
  # Resolves a logical model name + optional variant to concrete { model, variant?, ... }
  # merged with agentExtras if the slot has extras.
  resolveSlot = providerPriority: slotName: slotSpec: let
    logicalModel =
      if builtins.isString slotSpec
      then slotSpec
      else slotSpec.model;
    variant =
      if builtins.isAttrs slotSpec && slotSpec ? variant
      then {inherit (slotSpec) variant;}
      else {};
    providers = modelCatalog.${logicalModel}.providers;
    firstProvider = builtins.head (
      builtins.filter (p: builtins.hasAttr p providers) providerPriority
    );
    resolvedModel = providers.${firstProvider};
    extras = agentExtras.${slotName} or {};
  in
    {model = resolvedModel;} // variant // extras;

  generateConfig = {
    tier,
    providerPriority,
  }: let
    tierData = tierAssignments.${tier};
    resolvedAgents = lib.mapAttrs (resolveSlot providerPriority) tierData.agents;
    resolvedCategories = lib.mapAttrs (resolveSlot providerPriority) tierData.categories;
    meta = {
      generated_by = "opencode-config";
      inherit tier;
      priority = providerPriority;
    };
  in
    staticConfig
    // {
      "_meta" = meta;
      agents = resolvedAgents;
      categories = resolvedCategories;
    };

  # ── JSON serialization for shell script ───────────────────────────────────
  modelDataJson = builtins.toJSON modelCatalog;
  tierDataJson = builtins.toJSON tierAssignments;
  agentExtrasJson = builtins.toJSON agentExtras;
  staticConfigJson = builtins.toJSON staticConfig;
  defaultPriorityJson = builtins.toJSON defaultProviderPriority;
  providerNamesJson = builtins.toJSON providerNames;

  defaultConfigJson = builtins.toJSON (
    generateConfig {
      tier = cfg.defaultTier;
      providerPriority = defaultProviderPriority;
    }
  );

  # ── Shell script package ──────────────────────────────────────────────────
  opencodeConfig = pkgs.writeShellApplication {
    name = "opencode-config";
    runtimeInputs = [pkgs.jq pkgs.coreutils pkgs.fzf];
    text = ''
      # Baked-in model knowledge from Nix (do not edit — regenerated on rebuild)
      MODEL_CATALOG='${modelDataJson}'
      TIER_DATA='${tierDataJson}'
      AGENT_EXTRAS='${agentExtrasJson}'
      STATIC_CONFIG='${staticConfigJson}'
      DEFAULT_PRIORITY='${defaultPriorityJson}'
      PROVIDER_NAMES='${providerNamesJson}'

      ${builtins.readFile ./scripts/opencode-config.sh}
    '';
  };
in {
  options.custom.opencode.defaultTier = lib.mkOption {
    type = lib.types.enum ["balanced" "max" "budget"];
    default = "balanced";
    description = ''
      Default quality tier for opencode-config generator.
      Used when seeding the initial oh-my-opencode.json on first activation.
      - balanced: Good defaults — Claude Opus for orchestration, Codex for coding
      - max: Strongest available models across all roles
      - budget: Prioritizes OpenCode Go tier (GLM-5, Kimi K2.5, MiniMax) for economy
    '';
  };

  config = {
    home.packages = [opencodeConfig];

    # Seed default oh-my-opencode.json if absent; handle migration from old profiles system
    home.activation.bootstrapOpencodeConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      OPENCODE_DIR="${config.xdg.configHome}/opencode"
      OPENCODE_CONFIG="$OPENCODE_DIR/oh-my-opencode.json"

      mkdir -p "$OPENCODE_DIR"

      # Migration: detect stale symlink pointing to deleted Nix store profile path
      # (happens when upgrading from the old profiles module to this module)
      if [ -L "$OPENCODE_CONFIG" ]; then
        LINK_TARGET="$(readlink "$OPENCODE_CONFIG" 2>/dev/null || true)"
        if [ -n "$LINK_TARGET" ] && [ ! -e "$LINK_TARGET" ]; then
          echo "opencode-config: removing stale profile symlink → seeding fresh default"
          rm -f "$OPENCODE_CONFIG"
        fi
      fi

      # Seed default config if no config file exists yet
      if [ ! -f "$OPENCODE_CONFIG" ]; then
        cat > "$OPENCODE_CONFIG" <<'__OPENCODE_DEFAULT__'
${defaultConfigJson}
__OPENCODE_DEFAULT__
        echo "opencode-config: seeded default config (${cfg.defaultTier} tier, copilot-first)"
      fi
    '';
  };
}
