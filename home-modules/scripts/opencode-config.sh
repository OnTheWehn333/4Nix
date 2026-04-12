#!/usr/bin/env bash

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
OC_CONFIG_DIR="$CONFIG_HOME/opencode"
OC_CONFIG_FILE="$OC_CONFIG_DIR/oh-my-openagent.json"
OC_STATE_FILE="$OC_CONFIG_DIR/opencode-config-state.json"

get_config_path() {
  local project_flag="${1:-}"
  if [ "$project_flag" = "--project" ]; then
    echo ".opencode/oh-my-openagent.json"
  else
    echo "$OC_CONFIG_FILE"
  fi
}

provider_exists() {
  local provider="$1"
  echo "$PROVIDER_NAMES" | jq -e --arg p "$provider" 'has($p)' >/dev/null 2>&1
}

model_exists() {
  local model="$1"
  echo "$MODEL_CATALOG" | jq -e --arg m "$model" 'has($m)' >/dev/null 2>&1
}

normalize_priority_csv() {
  local input_csv="$1"

  local json
  json=$(echo "$input_csv" | jq -R '
    split(",")
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0))
  ')

  if [ "$(echo "$json" | jq 'length')" -eq 0 ]; then
    echo "ERROR: Priority list is empty" >&2
    return 1
  fi

  local invalid
  invalid=$(echo "$json" | jq -r --argjson providers "$PROVIDER_NAMES" '.[] | select($providers[.] == null)')
  if [ -n "$invalid" ]; then
    echo "ERROR: Unknown provider(s): $(echo "$invalid" | paste -sd ',')" >&2
    echo "Valid providers: $(echo "$PROVIDER_NAMES" | jq -r 'keys | join(", ")')" >&2
    return 1
  fi

  # Deduplicate while preserving user-specified order
  echo "$json" | jq -r '
    reduce .[] as $p (
      {seen: {}, result: []};
      if .seen[$p] then .
      else {seen: (.seen + {($p): true}), result: (.result + [$p])}
      end
    ) | .result | join(",")
  '
}

# Get momus model from smart-high model using model pairs
get_momus_model() {
  local smart_high_model="$1"
  echo "$MODEL_PAIRS" | jq -r --arg m "$smart_high_model" '.[$m] // "gpt-5-4"'
}

# Resolve a logical model to a concrete model ID based on provider priority
resolve_model() {
  local logical_model="$1"
  local priority_csv="$2"

  local providers_json
  providers_json=$(echo "$MODEL_CATALOG" | jq -c --arg m "$logical_model" '.[$m].providers // empty')
  if [ -z "$providers_json" ]; then
    echo "ERROR: Unknown model '$logical_model'" >&2
    return 1
  fi

  IFS=',' read -r -a providers <<< "$priority_csv"
  for provider in "${providers[@]}"; do
    local model_id
    model_id=$(echo "$providers_json" | jq -r --arg p "$provider" '.[$p] // empty')
    if [ -n "$model_id" ]; then
      echo "$model_id"
      return 0
    fi
  done

  echo "ERROR: No provider found for '$logical_model' in priority [$priority_csv]" >&2
  return 1
}

# Get fallback models for a logical model
get_fallbacks() {
  local logical_model="$1"
  local priority_csv="$2"

  local providers_json
  providers_json=$(echo "$MODEL_CATALOG" | jq -c --arg m "$logical_model" '.[$m].providers // empty')
  if [ -z "$providers_json" ]; then
    echo '[]'
    return 0
  fi

  # Get all matches in priority order
  local all_matches='[]'
  IFS=',' read -r -a providers <<< "$priority_csv"
  for provider in "${providers[@]}"; do
    local model_id
    model_id=$(echo "$providers_json" | jq -r --arg p "$provider" '.[$p] // empty')
    if [ -n "$model_id" ]; then
      all_matches=$(echo "$all_matches" | jq --arg m "$model_id" '. + [$m]')
    fi
  done

  # Return unique fallbacks (skip first as it's the primary)
  echo "$all_matches" | jq 'reduce .[] as $m ([]; if index($m) == null then . + [$m] else . end) | .[1:]'
}

# Build agent config with fallbacks and extras
build_agent_config() {
  local agent_name="$1"
  local logical_model="$2"
  local priority_csv="$3"

  local primary
  primary=$(resolve_model "$logical_model" "$priority_csv") || return 1

  local fallbacks
  fallbacks=$(get_fallbacks "$logical_model" "$priority_csv")

  local extras
  extras=$(echo "$AGENT_EXTRAS" | jq --arg n "$agent_name" '.[$n] // {}')

  local entry
  entry=$(jq -n --arg m "$primary" '{model:$m}')

  if [ "$(echo "$fallbacks" | jq 'length')" -gt 0 ]; then
    entry=$(echo "$entry" | jq --argjson f "$fallbacks" '. + {fallback_models:$f}')
  fi

  # Merge extras
  entry=$(echo "$entry $extras" | jq -s 'add')

  echo "$entry"
}

# Generate config from group models
generate_config_json() {
  local smart_high_model="${1:-kimi-k2-5}"
  local smart_low_model="${2:-minimax-m2-7}"
  local research_model="${3:-gemini-3-flash}"
  local priority_csv="$4"

  if [ -z "$priority_csv" ]; then
    echo "ERROR: Priority list is empty" >&2
    return 1
  fi

  local normalized_priority
  normalized_priority=$(normalize_priority_csv "$priority_csv") || return 1

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Get momus model from smart-high using model pairs
  local momus_model
  momus_model=$(get_momus_model "$smart_high_model")

  # Build agents JSON
  local agents_json='{}'

  # Smart-high agents
  local smart_high_agents
  smart_high_agents=$(echo "$AGENT_GROUPS" | jq -r '.["smart-high"] | .[]')
  for agent in $smart_high_agents; do
    local entry
    entry=$(build_agent_config "$agent" "$smart_high_model" "$normalized_priority") || return 1
    agents_json=$(echo "$agents_json" | jq --arg k "$agent" --argjson v "$entry" '. + {($k):$v}')
  done

  # Smart-low agents
  local smart_low_agents
  smart_low_agents=$(echo "$AGENT_GROUPS" | jq -r '.["smart-low"] | .[]')
  for agent in $smart_low_agents; do
    local entry
    entry=$(build_agent_config "$agent" "$smart_low_model" "$normalized_priority") || return 1
    agents_json=$(echo "$agents_json" | jq --arg k "$agent" --argjson v "$entry" '. + {($k):$v}')
  done

  # Research agents
  local research_agents
  research_agents=$(echo "$AGENT_GROUPS" | jq -r '.research | .[]')
  for agent in $research_agents; do
    local entry
    entry=$(build_agent_config "$agent" "$research_model" "$normalized_priority") || return 1
    agents_json=$(echo "$agents_json" | jq --arg k "$agent" --argjson v "$entry" '. + {($k):$v}')
  done

  # Momus (auto from smart-high)
  local momus_entry
  momus_entry=$(build_agent_config "momus" "$momus_model" "$normalized_priority") || return 1
  agents_json=$(echo "$agents_json" | jq --argjson v "$momus_entry" '. + {momus:$v}')

  # Fixed agents
  local hephaestus_entry
  hephaestus_entry=$(build_agent_config "hephaestus" "gpt-5-4" "$normalized_priority") || return 1
  agents_json=$(echo "$agents_json" | jq --argjson v "$hephaestus_entry" '. + {hephaestus:$v}')

  local multimodal_entry
  multimodal_entry=$(build_agent_config "multimodal-looker" "gemini-3-1-pro" "$normalized_priority") || return 1
  agents_json=$(echo "$agents_json" | jq --argjson v "$multimodal_entry" '. + {"multimodal-looker":$v}')

  # Default agents (build, OpenCode-Builder)
  local default_agents
  default_agents=$(echo "$DEFAULT_AGENT_MODELS" | jq -r 'to_entries[] | @base64')
  for row in $default_agents; do
    local agent model
    agent=$(echo "$row" | base64 -d | jq -r '.key')
    model=$(echo "$row" | base64 -d | jq -r '.value')
    local entry
    entry=$(build_agent_config "$agent" "$model" "$normalized_priority") || return 1
    agents_json=$(echo "$agents_json" | jq --arg k "$agent" --argjson v "$entry" '. + {($k):$v}')
  done

  # Categories
  local categories_json='{}'
  local default_categories
  default_categories=$(echo "$DEFAULT_CATEGORY_MODELS" | jq -r 'to_entries[] | @base64')
  for row in $default_categories; do
    local cat model
    cat=$(echo "$row" | base64 -d | jq -r '.key')
    model=$(echo "$row" | base64 -d | jq -r '.value')
    local resolved
    resolved=$(resolve_model "$model" "$normalized_priority") || return 1
    categories_json=$(echo "$categories_json" | jq --arg k "$cat" --arg m "$resolved" '. + {($k):{model:$m}}')
  done

  # Meta
  local priority_json
  priority_json=$(echo "$normalized_priority" | jq -R 'split(",")')

  local meta
  meta=$(jq -n \
    --arg smart_high "$smart_high_model" \
    --arg smart_low "$smart_low_model" \
    --arg research "$research_model" \
    --arg momus "$momus_model" \
    --argjson priority "$priority_json" \
    --arg ts "$timestamp" \
    '{generated_by:"opencode-config",smart_high:$smart_high,smart_low:$smart_low,research:$research,momus:$momus,priority:$priority,generated_at:$ts}')

  # Final config
  echo "$STATIC_CONFIG" | jq \
    --arg schema "$SCHEMA_URL" \
    --argjson meta "$meta" \
    --argjson agents "$agents_json" \
    --argjson cats "$categories_json" \
    '{"$schema":$schema} + . + {_meta:$meta, agents:$agents, categories:$cats}'
}

read_stored_providers() {
  if [ ! -f "$OC_STATE_FILE" ]; then
    return 0
  fi

  if ! jq -e '.providers and (.providers | type == "array") and (.providers | all(type == "string"))' "$OC_STATE_FILE" >/dev/null 2>&1; then
    echo "ERROR: Bad state file at $OC_STATE_FILE (expected JSON with string array .providers)" >&2
    return 1
  fi

  local stored
  stored=$(jq -r '.providers | join(",")' "$OC_STATE_FILE")
  if [ -n "$stored" ]; then
    normalize_priority_csv "$stored"
  fi
}

save_providers() {
  local priority_csv="$1"
  local normalized
  normalized=$(normalize_priority_csv "$priority_csv") || return 1

  mkdir -p "$OC_CONFIG_DIR"
  local priority_json
  priority_json=$(echo "$normalized" | jq -R 'split(",")')
  jq -n --argjson p "$priority_json" '{providers:$p}' > "$OC_STATE_FILE"
}

default_priority_csv() {
  echo "$DEFAULT_PRIORITY" | jq -r 'join(",")'
}

read_config_group_models() {
  local config_path="$1"

  if [ ! -f "$config_path" ]; then
    return 0
  fi

  if ! jq -e '._meta.smart_high and (._meta.smart_high | type == "string") and ._meta.smart_low and (._meta.smart_low | type == "string") and ._meta.research and (._meta.research | type == "string")' "$config_path" >/dev/null 2>&1; then
    return 0
  fi

  jq -c '{smart_high: ._meta.smart_high, smart_low: ._meta.smart_low, research: ._meta.research}' "$config_path"
}

save_group_models() {
  local smart_high="$1"
  local smart_low="$2"
  local research="$3"

  mkdir -p "$OC_CONFIG_DIR"
  jq -n \
    --arg smart_high "$smart_high" \
    --arg smart_low "$smart_low" \
    --arg research "$research" \
    '{smart_high:$smart_high,smart_low:$smart_low,research:$research}' > "$OC_CONFIG_DIR/group-models.json"
}

read_group_models() {
  local config_path="${1:-$OC_CONFIG_FILE}"

  if [ -f "$OC_CONFIG_DIR/group-models.json" ]; then
    cat "$OC_CONFIG_DIR/group-models.json"
  else
    local config_groups
    config_groups=$(read_config_group_models "$config_path")
    if [ -n "$config_groups" ]; then
      echo "$config_groups"
    else
      echo "$DEFAULT_GROUP_MODELS"
    fi
  fi
}

cmd_generate() {
  local project_flag=""
  local priority_flag=""
  local smart=""
  local smart_high=""
  local smart_low=""
  local research=""
  local group_args_provided=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project_flag="--project"; shift ;;
      --priority)
        [ $# -lt 2 ] && { echo "ERROR: --priority requires a value" >&2; return 1; }
        priority_flag="$2"
        shift 2
        ;;
      --smart)
        [ $# -lt 2 ] && { echo "ERROR: --smart requires a value" >&2; return 1; }
        smart="$2"
        group_args_provided="1"
        shift 2
        ;;
      --smart-high)
        [ $# -lt 2 ] && { echo "ERROR: --smart-high requires a value" >&2; return 1; }
        smart_high="$2"
        group_args_provided="1"
        shift 2
        ;;
      --smart-low)
        [ $# -lt 2 ] && { echo "ERROR: --smart-low requires a value" >&2; return 1; }
        smart_low="$2"
        group_args_provided="1"
        shift 2
        ;;
      --research)
        [ $# -lt 2 ] && { echo "ERROR: --research requires a value" >&2; return 1; }
        research="$2"
        group_args_provided="1"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  local config_path
  config_path=$(get_config_path "$project_flag")

  # Get provider priority from explicit input, stored state, current config, or the baked-in default.
  local priority_csv=""
  if [ -n "$priority_flag" ]; then
    priority_csv=$(normalize_priority_csv "$priority_flag") || return 1
  else
    priority_csv=$(read_stored_providers) || return 1
    if [ -z "$priority_csv" ]; then
      priority_csv=$(default_priority_csv)
    fi
  fi

  save_providers "$priority_csv" || return 1

  # Get stored group models or fall back to config metadata/defaults.
  local stored_groups
  stored_groups=$(read_group_models "$config_path")

  if [ -n "$smart" ]; then
    smart_high="$smart"
    smart_low="$smart"
  fi

  if [ -z "$smart_high" ]; then
    smart_high=$(echo "$stored_groups" | jq -r '.smart_high // "kimi-k2-5"')
  fi
  if [ -z "$smart_low" ]; then
    smart_low=$(echo "$stored_groups" | jq -r '.smart_low // "minimax-m2-7"')
  fi
  if [ -z "$research" ]; then
    research=$(echo "$stored_groups" | jq -r '.research // "gemini-3-flash"')
  fi

  if [ -z "$group_args_provided" ] && [ -t 0 ] && [ -t 1 ]; then
    echo "Configure group models (pick a model or keep the current one):"
    smart_high=$(pick_group_model "smart-high" "$smart_high") || return 1
    smart_low=$(pick_group_model "smart-low" "$smart_low") || return 1
    research=$(pick_group_model "research" "$research") || return 1
  fi

  # Validate models
  if ! model_exists "$smart_high"; then
    echo "ERROR: Unknown model '$smart_high'" >&2
    return 1
  fi
  if ! model_exists "$smart_low"; then
    echo "ERROR: Unknown model '$smart_low'" >&2
    return 1
  fi
  if ! model_exists "$research"; then
    echo "ERROR: Unknown model '$research'" >&2
    return 1
  fi

  # Save group models
  save_group_models "$smart_high" "$smart_low" "$research"

  if [ "$project_flag" = "--project" ]; then
    if [ ! -d ".git" ] && [ ! -d ".opencode" ]; then
      echo "ERROR: Not in a project directory (no .git or .opencode found)" >&2
      echo "Hint: Run from a git repo root, or create .opencode/ first" >&2
      return 1
    fi
    mkdir -p .opencode
  else
    mkdir -p "$OC_CONFIG_DIR"
  fi

  local momus_model
  momus_model=$(get_momus_model "$smart_high")

  echo "Generating config:"
  echo "  smart-high: $smart_high (sisyphus, prometheus, oracle, metis, plan)"
  echo "  smart-low:  $smart_low (sisyphus-junior, atlas)"
  echo "  research:   $research (librarian, explore)"
  echo "  momus:      $momus_model (auto-paired)"
  echo "  priority:   $priority_csv"

  local config_json
  config_json=$(generate_config_json "$smart_high" "$smart_low" "$research" "$priority_csv") || return 1
  printf '%s\n' "$config_json" > "$config_path"

  echo "✓ Written to $config_path"
}

pick_model() {
  local prompt="${1:-Select model}"

  echo "$MODEL_CATALOG" | jq -r 'keys[]' | \
    fzf --prompt="$prompt> " --height=50% --reverse
}

pick_group_model() {
  local group_name="$1"
  local current_model="$2"

  local selected
  selected=$(
    {
      printf 'keep current — %s\n' "$current_model"
      echo "$MODEL_CATALOG" | jq -r --arg current "$current_model" 'keys[] | select(. != $current)'
    } | fzf --prompt="Select ${group_name} model> " --height=50% --reverse || true
  )

  if [ -z "$selected" ]; then
    echo "ERROR: No model selected" >&2
    return 1
  fi

  if [ "$selected" = "keep current — $current_model" ]; then
    echo "$current_model"
  else
    echo "$selected"
  fi
}

cmd_set() {
  local project_flag=""
  local priority_flag=""
  local group=""
  local group_model=""
  local agent_name=""
  local agent_model=""
  local category_name=""
  local category_model=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project_flag="--project"; shift ;;
      --priority)
        [ $# -lt 2 ] && { echo "ERROR: --priority requires a value" >&2; return 1; }
        priority_flag="$2"
        shift 2
        ;;
      --group)
        [ $# -lt 3 ] && { echo "ERROR: --group requires GROUP MODEL" >&2; return 1; }
        group="$2"
        group_model="$3"
        shift 3
        ;;
      --agent)
        [ $# -lt 3 ] && { echo "ERROR: --agent requires NAME MODEL" >&2; return 1; }
        agent_name="$2"
        agent_model="$3"
        shift 3
        ;;
      --category)
        [ $# -lt 3 ] && { echo "ERROR: --category requires NAME MODEL" >&2; return 1; }
        category_name="$2"
        category_model="$3"
        shift 3
        ;;
      *)
        echo "Unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  local config_path
  config_path=$(get_config_path "$project_flag")

  if [ ! -f "$config_path" ]; then
    echo "ERROR: No config found at $config_path. Run 'opencode-config generate' first." >&2
    return 1
  fi

  local current
  current=$(<"$config_path")

  # Get current group models
  local current_smart_high current_smart_low current_research
  current_smart_high=$(echo "$current" | jq -r '._meta.smart_high // "kimi-k2-5"')
  current_smart_low=$(echo "$current" | jq -r '._meta.smart_low // "minimax-m2-7"')
  current_research=$(echo "$current" | jq -r '._meta.research // "gemini-3-flash"')

  # Interactive mode if no args
  if [ -z "$group" ] && [ -z "$agent_name" ] && [ -z "$category_name" ] && [ -z "$priority_flag" ]; then
    if [ ! -t 0 ] || [ ! -t 1 ]; then
      echo "ERROR: Interactive mode requires a TTY. Use explicit arguments:" >&2
      echo "  opencode-config set --group smart-high MODEL" >&2
      echo "  opencode-config set --agent NAME MODEL" >&2
      return 1
    fi

    echo "What do you want to change?"
    local target_type
    target_type=$(printf '%s\n' \
      'smart — Set both smart groups together' \
      'smart-high — Main orchestration agents (sisyphus, prometheus, oracle, metis, plan)' \
      'smart-low — Execution agents (sisyphus-junior, atlas)' \
      'research — Research agents (librarian, explore)' \
      'agent — Specific agent' \
      'category — Task category' \
      'priority — Provider priority' | \
      fzf --prompt="Select type> " --height=35% --reverse | \
      jq -R 'split(" — ")[0]' -r)

    if [ -z "$target_type" ]; then
      echo "ERROR: Nothing selected" >&2
      return 1
    fi

    case "$target_type" in
      smart|smart-high|smart-low|research)
        group="$target_type"
        group_model=$(pick_model)
        if [ -z "$group_model" ]; then
          echo "ERROR: No model selected" >&2
          return 1
        fi
        ;;
      agent)
        agent_name=$(echo "$current" | jq -r '.agents | to_entries[] | .key + " — " + .value.model' | \
          fzf --prompt="Select agent> " --height=50% --reverse | jq -R 'split(" — ")[0]' -r)
        if [ -z "$agent_name" ]; then
          echo "ERROR: No agent selected" >&2
          return 1
        fi
        agent_model=$(pick_model)
        if [ -z "$agent_model" ]; then
          echo "ERROR: No model selected" >&2
          return 1
        fi
        ;;
      category)
        category_name=$(echo "$current" | jq -r '.categories | to_entries[] | .key + " — " + .value.model' | \
          fzf --prompt="Select category> " --height=50% --reverse | jq -R 'split(" — ")[0]' -r)
        if [ -z "$category_name" ]; then
          echo "ERROR: No category selected" >&2
          return 1
        fi
        category_model=$(pick_model)
        if [ -z "$category_model" ]; then
          echo "ERROR: No model selected" >&2
          return 1
        fi
        ;;
      priority)
        echo "Configure provider priority order (highest priority first):"
        local remaining_providers
        remaining_providers=$(echo "$PROVIDER_DISPLAY_ORDER" | jq -r '.[] | .key + " — " + .value')

        local selected='[]'
        local priority_count=1

        while [ -n "$remaining_providers" ]; do
          local count
          count=$(echo "$remaining_providers" | wc -l)
          [ "$count" -eq 0 ] && break

          local prompt_text
          if [ "$priority_count" -eq 1 ]; then
            prompt_text="Select #1 priority provider (highest)"
          else
            prompt_text="Select #''${priority_count} priority provider (or Esc to finish)"
          fi

          local provider
          provider=$(echo "$remaining_providers" | fzf --prompt="$prompt_text> " --height=40% --reverse || true)
          [ -z "$provider" ] && break

          local provider_key="${provider%% — *}"
          selected=$(echo "$selected" | jq --arg p "$provider_key" '. + [$p]')
          remaining_providers=$(echo "$remaining_providers" | grep -v "^$provider_key —")
          priority_count=$((priority_count + 1))
        done

        if [ "$(echo "$selected" | jq 'length')" -eq 0 ]; then
          echo "ERROR: No providers selected" >&2
          return 1
        fi

        priority_flag=$(echo "$selected" | jq -r 'join(",")')
        ;;
    esac
  fi

  # Handle group changes
  if [ -n "$group" ]; then
    if [ -z "$group_model" ]; then
      echo "ERROR: --group requires a model (use interactive mode or --group GROUP MODEL)" >&2
      return 1
    fi

    if ! model_exists "$group_model"; then
      echo "ERROR: Unknown model '$group_model'" >&2
      return 1
    fi

    # Update the appropriate group model
    case "$group" in
      smart)
        current_smart_high="$group_model"
        current_smart_low="$group_model"
        echo "✓ Set smart-high and smart-low to $group_model"
        ;;
      smart-high)
        current_smart_high="$group_model"
        echo "✓ Set smart-high to $group_model (sisyphus, prometheus, oracle, metis, plan)"
        ;;
      smart-low)
        current_smart_low="$group_model"
        echo "✓ Set smart-low to $group_model (sisyphus-junior, atlas)"
        ;;
      research)
        current_research="$group_model"
        echo "✓ Set research to $group_model (librarian, explore)"
        ;;
      *)
        echo "ERROR: Unknown group '$group'. Valid: smart, smart-high, smart-low, research" >&2
        return 1
        ;;
    esac

    # Save group models and regenerate
    save_group_models "$current_smart_high" "$current_smart_low" "$current_research"

    local priority_csv
    priority_csv=$(echo "$current" | jq -r '._meta.priority | join(",")')
    if [ -z "$priority_csv" ]; then
      priority_csv=$(read_stored_providers) || return 1
    fi
    if [ -z "$priority_csv" ]; then
      priority_csv=$(echo "$DEFAULT_PRIORITY" | jq -r 'join(",")')
    fi

    local config_json
    config_json=$(generate_config_json "$current_smart_high" "$current_smart_low" "$current_research" "$priority_csv") || return 1
    printf '%s\n' "$config_json" > "$config_path"

    # Show momus pairing
    local momus_model
    momus_model=$(get_momus_model "$current_smart_high")
    echo "✓ Updated config (momus auto-paired: $momus_model)"
    return 0
  fi

  # Handle individual agent changes
  if [ -n "$agent_name" ]; then
    if ! echo "$current" | jq -e --arg n "$agent_name" '.agents[$n]' >/dev/null 2>&1; then
      echo "ERROR: Invalid agent name '$agent_name'" >&2
      echo "Valid agents: $(echo "$current" | jq -r '.agents | keys | join(", ")')" >&2
      return 1
    fi

    if ! model_exists "$agent_model"; then
      echo "ERROR: Unknown model '$agent_model'" >&2
      return 1
    fi

    local priority_csv
    priority_csv=$(echo "$current" | jq -r '._meta.priority | join(",")')

    local entry
    entry=$(build_agent_config "$agent_name" "$agent_model" "$priority_csv") || return 1

    local updated
    updated=$(echo "$current" | jq --arg n "$agent_name" --argjson e "$entry" '.agents[$n] = $e')
    printf '%s\n' "$updated" > "$config_path"
    echo "✓ Updated agent '$agent_name' → $(echo "$entry" | jq -r '.model')"
    return 0
  fi

  # Handle category changes
  if [ -n "$category_name" ]; then
    if ! echo "$current" | jq -e --arg n "$category_name" '.categories[$n]' >/dev/null 2>&1; then
      echo "ERROR: Invalid category name '$category_name'" >&2
      echo "Valid categories: $(echo "$current" | jq -r '.categories | keys | join(", ")')" >&2
      return 1
    fi

    if ! model_exists "$category_model"; then
      echo "ERROR: Unknown model '$category_model'" >&2
      return 1
    fi

    local priority_csv
    priority_csv=$(echo "$current" | jq -r '._meta.priority | join(",")')

    local resolved
    resolved=$(resolve_model "$category_model" "$priority_csv") || return 1

    local updated
    updated=$(echo "$current" | jq --arg n "$category_name" --arg m "$resolved" '.categories[$n].model = $m')
    printf '%s\n' "$updated" > "$config_path"
    echo "✓ Updated category '$category_name' → $resolved"
    return 0
  fi

  # Handle priority changes
  if [ -n "$priority_flag" ]; then
    local priority_csv
    priority_csv=$(normalize_priority_csv "$priority_flag") || return 1
    save_providers "$priority_csv" || return 1

    local config_json
    config_json=$(generate_config_json "$current_smart_high" "$current_smart_low" "$current_research" "$priority_csv") || return 1
    printf '%s\n' "$config_json" > "$config_path"
    echo "✓ Updated config with new provider priority"
    return 0
  fi
}

cmd_show() {
  local project_flag="${1:-}"
  local user_config="$OC_CONFIG_FILE"
  local project_config=".opencode/oh-my-openagent.json"

  local effective_config="$user_config"
  local scope="user"

  if [ "$project_flag" = "--project" ]; then
    effective_config="$project_config"
    scope="project"
  elif [ -f "$project_config" ]; then
    effective_config="$project_config"
    scope="project"
  fi

  if [ ! -f "$effective_config" ]; then
    echo "No config found. Run 'opencode-config generate' to create one."
    return 0
  fi

  local config_data
  config_data=$(<"$effective_config")
  if ! echo "$config_data" | jq -e '.' >/dev/null 2>&1; then
    echo "ERROR: Config at $effective_config is not valid JSON" >&2
    return 1
  fi

  local smart_high smart_low research momus priority
  smart_high=$(echo "$config_data" | jq -r '._meta.smart_high // "unknown"')
  smart_low=$(echo "$config_data" | jq -r '._meta.smart_low // "unknown"')
  research=$(echo "$config_data" | jq -r '._meta.research // "unknown"')
  momus=$(echo "$config_data" | jq -r '._meta.momus // "unknown"')
  priority=$(echo "$config_data" | jq -r '._meta.priority // [] | join(", ")')

  echo "Scope:      $scope ($(realpath "$effective_config" 2>/dev/null || echo "$effective_config"))"
  echo ""
  echo "Group Models:"
  echo "  smart-high: $smart_high (sisyphus, prometheus, oracle, metis, plan)"
  echo "  smart-low:  $smart_low (sisyphus-junior, atlas)"
  echo "  research:   $research (librarian, explore)"
  echo "  momus:      $momus (auto-paired with smart-high)"
  echo ""
  echo "Priority:   ${priority:-unknown}"
  echo ""

  printf "%-28s %-44s %s\n" "Agent" "Model" "Variant"
  printf "%-28s %-44s %s\n" "────────────────────────────" "────────────────────────────────────────────" "───────"
  echo "$config_data" | jq -r '.agents | to_entries | sort_by(.key) | .[] | [.key, .value.model, (.value.variant // "-")] | @tsv' | while IFS=$'\t' read -r name model variant; do
    printf "%-28s %-44s %s\n" "$name" "$model" "$variant"
  done

  echo
  printf "%-28s %-44s %s\n" "Category" "Model" "Variant"
  printf "%-28s %-44s %s\n" "────────────────────────────" "────────────────────────────────────────────" "───────"
  echo "$config_data" | jq -r '.categories | to_entries | sort_by(.key) | .[] | [.key, .value.model, (.value.variant // "-")] | @tsv' | while IFS=$'\t' read -r name model variant; do
    printf "%-28s %-44s %s\n" "$name" "$model" "$variant"
  done
}

cmd_providers() {
  local action="${1:-list}"
  shift || true

  case "$action" in
    list)
      if [ -f "$OC_STATE_FILE" ]; then
        if ! jq -e '.providers and (.providers | type == "array") and (.providers | all(type == "string"))' "$OC_STATE_FILE" >/dev/null 2>&1; then
          echo "ERROR: Bad state file at $OC_STATE_FILE" >&2
          return 1
        fi
        echo "Stored providers (in priority order):"
        jq -r '.providers[]' "$OC_STATE_FILE" | nl -ba
      else
        echo "No stored providers. Run 'opencode-config providers set openai,google,opencode-go,copilot,opencode'"
        echo
        echo "Available providers:"
        echo "$PROVIDER_NAMES" | jq -r 'to_entries[] | "  " + .key + " — " + .value'
      fi
      ;;
    set)
      local csv="${1:-}"
      if [ -z "$csv" ]; then
        echo "Usage: opencode-config providers set PROVIDER1,PROVIDER2,..." >&2
        return 1
      fi
      local normalized
      normalized=$(normalize_priority_csv "$csv") || return 1
      save_providers "$normalized" || return 1
      echo "✓ Providers saved: $(read_stored_providers)"
      ;;
    add)
      local provider="${1:-}"
      if [ -z "$provider" ]; then
        echo "Usage: opencode-config providers add PROVIDER" >&2
        return 1
      fi
      if ! provider_exists "$provider"; then
        echo "ERROR: Unknown provider '$provider'" >&2
        echo "Valid providers: $(echo "$PROVIDER_NAMES" | jq -r 'keys | join(", ")')" >&2
        return 1
      fi
      local current_csv
      current_csv=$(read_stored_providers) || return 1
      if [ -n "$current_csv" ]; then
        save_providers "$current_csv,$provider" || return 1
      else
        save_providers "$provider" || return 1
      fi
      echo "✓ Added provider: $provider"
      ;;
    remove)
      local provider="${1:-}"
      if [ -z "$provider" ]; then
        echo "Usage: opencode-config providers remove PROVIDER" >&2
        return 1
      fi
      if [ ! -f "$OC_STATE_FILE" ]; then
        echo "ERROR: No state file found at $OC_STATE_FILE" >&2
        return 1
      fi
      if ! provider_exists "$provider"; then
        echo "ERROR: Unknown provider '$provider'" >&2
        echo "Valid providers: $(echo "$PROVIDER_NAMES" | jq -r 'keys | join(", ")')" >&2
        return 1
      fi
      if ! jq -e '.providers and (.providers | type == "array") and (.providers | all(type == "string"))' "$OC_STATE_FILE" >/dev/null 2>&1; then
        echo "ERROR: Bad state file at $OC_STATE_FILE" >&2
        return 1
      fi
      local updated
      updated=$(jq --arg p "$provider" '.providers | map(select(. != $p)) | {providers:.}' "$OC_STATE_FILE")
      printf '%s\n' "$updated" > "$OC_STATE_FILE"
      echo "✓ Removed provider: $provider"
      ;;
    *)
      echo "Usage: opencode-config providers {list|set P1,P2,...|add P|remove P}" >&2
      return 1
      ;;
  esac
}

usage() {
  cat <<'EOF'
opencode-config — oh-my-openagent.json generator

Usage:
  opencode-config generate [--smart MODEL] [--smart-high MODEL] [--smart-low MODEL] [--research MODEL] [--priority P1,P2,...] [--project]
  opencode-config set (--group GROUP MODEL | --agent NAME MODEL | --category NAME MODEL | --priority P1,P2,...) [--project]
  opencode-config show [--project]
  opencode-config providers {list|set P1,P2,...|add P|remove P}

Groups:
  smart      — Set both smart-high and smart-low to the same model
  smart-high — Main orchestration (sisyphus, prometheus, oracle, metis, plan)
  smart-low  — Execution agents (sisyphus-junior, atlas)
  research   — Research agents (librarian, explore)

Examples:
  opencode-config generate --smart kimi-k2-5          # Kimi for both smart groups
  opencode-config set --group smart-high claude-opus    # Opus for main agents
  opencode-config set --group smart kimi-k2-5          # Kimi for both smart groups
  opencode-config set --agent hephaestus codex-5-3     # Specific agent override

Note: momus is auto-paired with smart-high model using model pairs:
  claude-opus ↔ gpt-5-4 | glm-5 ↔ kimi-k2-5 | minimax-m2-7 ↔ kimi-k2-5
EOF
}

command="${1:-}"
shift || true

case "$command" in
  generate) cmd_generate "$@" ;;
  set) cmd_set "$@" ;;
  show) cmd_show "$@" ;;
  providers) cmd_providers "$@" ;;
  help|--help|-h) usage ;;
  *) usage; exit 1 ;;
esac
