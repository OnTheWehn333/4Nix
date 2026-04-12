{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.opencode;

  noLongRunningProcesses = ''
    PROCESS EXECUTION RULE: Never start long-lived or background processes (servers, watchers, docker-compose up, nix-build with --keep-going, dev servers, etc.) directly. Instead, output the exact command so the user can run it in their own tmux session. Short-lived commands that complete quickly (tests, linters, single builds, git operations) are fine to run directly.'';

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

  schemaUrl = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";

  staticConfig = {
    google_auth = false;
    git_master = {
      commit_footer = false;
      include_co_authored_by = false;
    };
  };

  providerNames = {
    copilot = "GitHub Copilot (subscription)";
    openai = "OpenAI (direct OAuth)";
    google = "Google";
    "opencode-go" = "OpenCode Go (flat-rate)";
    opencode = "OpenCode Zen (pay-per-token)";
  };

  defaultProviderPriority = ["openai" "google" "opencode-go" "copilot" "opencode"];

  providerDisplayOrder = map (p: {
    key = p;
    value = providerNames.${p};
  }) defaultProviderPriority;

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

  # Note: modelPairs is intentionally asymmetric.
  # If smart-high is minimax-m2-7, momus pairs with kimi-k2-5.
  # But if smart-high is kimi-k2-5, momus pairs with glm-5.
  modelPairs = {
    claude-opus = "gpt-5-4";
    gpt-5-4 = "claude-opus";
    glm-5 = "kimi-k2-5";
    kimi-k2-5 = "glm-5";
    minimax-m2-7 = "kimi-k2-5";
  };

  agentGroups = {
    "smart-high" = ["sisyphus" "prometheus" "oracle" "metis" "plan"];
    "smart-low" = ["sisyphus-junior" "atlas"];
    research = ["librarian" "explore"];
  };

  defaultGroupModelsByTier = {
    balanced = {
      "smart-high" = "claude-opus";
      "smart-low" = "claude-sonnet";
      research = "gemini-3-flash";
    };
    max = {
      "smart-high" = "claude-opus";
      "smart-low" = "claude-opus";
      research = "gemini-3-flash";
    };
    budget = {
      "smart-high" = "kimi-k2-5";
      "smart-low" = "minimax-m2-7";
      research = "gemini-3-flash";
    };
  };

  defaultGroupModels = defaultGroupModelsByTier.${cfg.defaultTier};

  shellDefaultGroupModels = {
    smart_high = defaultGroupModels."smart-high";
    smart_low = defaultGroupModels."smart-low";
    research = defaultGroupModels.research;
  };

  fixedAgentModels = {
    hephaestus = "gpt-5-4";
    "multimodal-looker" = "gemini-3-1-pro";
  };

  defaultAgentModels = {
    build = "codex-5-3";
    OpenCode-Builder = "codex-5-3";
  };

  defaultCategoryModels = {
    visual-engineering = "gemini-3-1-pro";
    ultrabrain = "gpt-5-4";
    deep = "codex-5-3";
    artistry = "gemini-3-1-pro";
    quick = "gpt-5-4-mini";
    unspecified-high = "claude-opus";
    unspecified-low = "claude-sonnet";
    writing = "gemini-3-flash";
  };

  slotLogicalModel = slotSpec:
    if builtins.isString slotSpec
    then slotSpec
    else slotSpec.model;

  slotHasVariant = slotSpec:
    builtins.isAttrs slotSpec && slotSpec ? variant;

  slotVariantAttrs = slotSpec:
    if slotHasVariant slotSpec
    then {inherit (slotSpec) variant;}
    else {};

  resolveSlot = providerPriority: slotName: slotSpec: let
    logicalModel = slotLogicalModel slotSpec;
    variantAttrs = slotVariantAttrs slotSpec;
    providers = modelCatalog.${logicalModel}.providers;
    availableProviders = builtins.filter (p: builtins.hasAttr p providers) providerPriority;
    resolvedModel =
      if availableProviders == []
      then builtins.throw "No provider found for '${logicalModel}' in slot '${slotName}' with priority [${builtins.concatStringsSep "," providerPriority}]"
      else providers.${builtins.head availableProviders};
    fallbackModels = lib.unique (map (p: providers.${p}) (builtins.tail availableProviders));
    fallbackAttrs =
      if fallbackModels == []
      then {}
      else {
        fallback_models =
          if slotHasVariant slotSpec
          then map (model: {inherit model;} // variantAttrs) fallbackModels
          else fallbackModels;
      };
    extras = agentExtras.${slotName} or {};
  in
    {model = resolvedModel;} // variantAttrs // fallbackAttrs // extras;

  resolveCategorySlot = providerPriority: slotName: slotSpec:
    builtins.removeAttrs (resolveSlot providerPriority slotName slotSpec) ["fallback_models" "prompt_append" "permission"];

  generateGroupConfig = {
    groupModels,
    providerPriority,
  }: let
    smartHighSlot = groupModels."smart-high";
    smartLowSlot = groupModels."smart-low";
    researchSlot = groupModels.research;
    smartHighLogicalModel = slotLogicalModel smartHighSlot;
    smartLowLogicalModel = slotLogicalModel smartLowSlot;
    researchLogicalModel = slotLogicalModel researchSlot;
    momusLogicalModel = modelPairs.${smartHighLogicalModel} or "gpt-5-4";
    resolvedAgents =
      lib.genAttrs agentGroups."smart-high" (name: resolveSlot providerPriority name smartHighSlot)
      // lib.genAttrs agentGroups."smart-low" (name: resolveSlot providerPriority name smartLowSlot)
      // lib.genAttrs agentGroups.research (name: resolveSlot providerPriority name researchSlot)
      // lib.mapAttrs (resolveSlot providerPriority) fixedAgentModels
      // lib.mapAttrs (resolveSlot providerPriority) defaultAgentModels
      // {
        momus = resolveSlot providerPriority "momus" momusLogicalModel;
      };
    resolvedCategories = lib.mapAttrs (resolveCategorySlot providerPriority) defaultCategoryModels;
    meta = {
      generated_by = "opencode-config";
      preset = cfg.defaultTier;
      smart_high = smartHighLogicalModel;
      smart_low = smartLowLogicalModel;
      research = researchLogicalModel;
      momus = momusLogicalModel;
      priority = providerPriority;
    };
  in
    {"$schema" = schemaUrl;}
    // staticConfig
    // {
      _meta = meta;
      agents = resolvedAgents;
      categories = resolvedCategories;
    };

  modelDataJson = builtins.toJSON modelCatalog;
  modelPairsJson = builtins.toJSON modelPairs;
  agentGroupsJson = builtins.toJSON agentGroups;
  defaultGroupModelsJson = builtins.toJSON shellDefaultGroupModels;
  defaultAgentModelsJson = builtins.toJSON defaultAgentModels;
  defaultCategoryModelsJson = builtins.toJSON defaultCategoryModels;
  agentExtrasJson = builtins.toJSON agentExtras;
  staticConfigJson = builtins.toJSON staticConfig;
  defaultPriorityJson = builtins.toJSON defaultProviderPriority;
  providerNamesJson = builtins.toJSON providerNames;
  providerDisplayOrderJson = builtins.toJSON providerDisplayOrder;

  defaultConfigJson = builtins.toJSON (
    generateGroupConfig {
      groupModels = defaultGroupModels;
      providerPriority = defaultProviderPriority;
    }
  );

  defaultProviderStateJson = builtins.toJSON {providers = defaultProviderPriority;};
  defaultGroupStateJson = builtins.toJSON shellDefaultGroupModels;

  opencodeConfig = pkgs.writeShellApplication {
    name = "opencode-config";
    runtimeInputs = [pkgs.jq pkgs.coreutils pkgs.fzf];
    text = ''
      MODEL_CATALOG='${modelDataJson}'
      MODEL_PAIRS='${modelPairsJson}'
      AGENT_GROUPS='${agentGroupsJson}'
      DEFAULT_GROUP_MODELS='${defaultGroupModelsJson}'
      DEFAULT_AGENT_MODELS='${defaultAgentModelsJson}'
      DEFAULT_CATEGORY_MODELS='${defaultCategoryModelsJson}'
      AGENT_EXTRAS='${agentExtrasJson}'
      STATIC_CONFIG='${staticConfigJson}'
      SCHEMA_URL='${schemaUrl}'
      DEFAULT_PRIORITY='${defaultPriorityJson}'
      PROVIDER_NAMES='${providerNamesJson}'
      PROVIDER_DISPLAY_ORDER='${providerDisplayOrderJson}'

      ${builtins.readFile ./scripts/opencode-config.sh}
    '';
  };
in {
  options.custom.opencode.defaultTier = lib.mkOption {
    type = lib.types.enum ["balanced" "max" "budget"];
    default = "balanced";
    description = ''
      Default preset for opencode-config group models.
      Used when seeding the initial oh-my-openagent.json on first activation.
      - balanced: Claude Opus for smart-high, Claude Sonnet for smart-low, Gemini Flash for research
      - max: Claude Opus for both smart groups, Gemini Flash for research
      - budget: Kimi K2.5 for smart-high, MiniMax M2.7 for smart-low, Gemini Flash for research
    '';
  };

  config = {
    home.packages = [opencodeConfig];

    home.activation.bootstrapOpencodeConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      OPENCODE_DIR="${config.xdg.configHome}/opencode"
      OPENCODE_CONFIG="$OPENCODE_DIR/oh-my-openagent.json"
      LEGACY_CONFIG="$OPENCODE_DIR/oh-my-opencode.json"
      OPENCODE_STATE="$OPENCODE_DIR/opencode-config-state.json"
      GROUP_MODELS_STATE="$OPENCODE_DIR/group-models.json"
      SEEDED_DEFAULT_CONFIG=0

      mkdir -p "$OPENCODE_DIR"

      if [ -L "$OPENCODE_CONFIG" ]; then
        LINK_TARGET="$(readlink "$OPENCODE_CONFIG" 2>/dev/null || true)"
        if [ -n "$LINK_TARGET" ] && [ ! -e "$LINK_TARGET" ]; then
          echo "opencode-config: removing stale config symlink → seeding fresh default"
          rm -f "$OPENCODE_CONFIG"
        fi
      fi

      if [ ! -f "$OPENCODE_CONFIG" ] && [ -f "$LEGACY_CONFIG" ] && [ ! -L "$LEGACY_CONFIG" ]; then
        mv "$LEGACY_CONFIG" "$OPENCODE_CONFIG"
        echo "opencode-config: migrated oh-my-opencode.json → oh-my-openagent.json"
      fi

      rm -f "$LEGACY_CONFIG.bak"

      if [ ! -f "$OPENCODE_CONFIG" ]; then
        cat > "$OPENCODE_CONFIG" <<'__OPENCODE_DEFAULT__'
${defaultConfigJson}
__OPENCODE_DEFAULT__
        echo "opencode-config: seeded default config (${cfg.defaultTier} preset)"
        SEEDED_DEFAULT_CONFIG=1
      fi

      if [ "$SEEDED_DEFAULT_CONFIG" = 1 ] && [ ! -f "$OPENCODE_STATE" ]; then
        cat > "$OPENCODE_STATE" <<'__OPENCODE_DEFAULT_STATE__'
${defaultProviderStateJson}
__OPENCODE_DEFAULT_STATE__
        echo "opencode-config: seeded default provider priority state"
      fi

      if [ "$SEEDED_DEFAULT_CONFIG" = 1 ] && [ ! -f "$GROUP_MODELS_STATE" ]; then
        cat > "$GROUP_MODELS_STATE" <<'__OPENCODE_DEFAULT_GROUPS__'
${defaultGroupStateJson}
__OPENCODE_DEFAULT_GROUPS__
        echo "opencode-config: seeded default group model state (${cfg.defaultTier} preset)"
      fi
    '';
  };
}
