#!/usr/bin/env bash

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
OC_CONFIG_DIR="$CONFIG_HOME/opencode"
OC_CONFIG_FILE="$OC_CONFIG_DIR/oh-my-opencode.json"
OC_STATE_FILE="$OC_CONFIG_DIR/opencode-config-state.json"

get_config_path() {
  local project_flag="${1:-}"
  if [ "$project_flag" = "--project" ]; then
    echo ".opencode/oh-my-opencode.json"
  else
    echo "$OC_CONFIG_FILE"
  fi
}

provider_exists() {
  local provider="$1"
  echo "$PROVIDER_NAMES" | jq -e --arg p "$provider" 'has($p)' >/dev/null 2>&1
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

  # Deduplicate while preserving user-specified order (jq 'unique' sorts — avoid it)
  echo "$json" | jq -r '
    reduce .[] as $p (
      {seen: {}, result: []};
      if .seen[$p] then .
      else {seen: (.seen + {($p): true}), result: (.result + [$p])}
      end
    ) | .result | join(",")
  '
}

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

generate_config_json() {
  local tier="$1"
  local priority_csv="$2"
  local orchestrator_override="${3:-}"

  if ! echo "$TIER_DATA" | jq -e --arg t "$tier" 'has($t)' >/dev/null 2>&1; then
    echo "ERROR: Invalid tier '$tier'. Valid: balanced, max, budget" >&2
    return 1
  fi

  if [ -z "$priority_csv" ]; then
    echo "ERROR: Priority list is empty" >&2
    return 1
  fi

  local normalized_priority
  normalized_priority=$(normalize_priority_csv "$priority_csv") || return 1

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local priority_json
  priority_json=$(echo "$normalized_priority" | jq -R 'split(",")')

  local agents_json
  agents_json='{}'
  while IFS='=' read -r slot_name slot_spec; do
    local logical_model
    logical_model=$(echo "$slot_spec" | jq -r 'if type=="string" then . else .model end')
    local variant_value
    variant_value=$(echo "$slot_spec" | jq -r 'if type=="object" and has("variant") then .variant else empty end')

    local resolved_model
    resolved_model=$(resolve_model "$logical_model" "$normalized_priority") || return 1

    local entry
    entry=$(jq -n --arg m "$resolved_model" '{model:$m}')
    if [ -n "$variant_value" ]; then
      entry=$(echo "$entry" | jq --arg v "$variant_value" '. + {variant:$v}')
    fi

    local extras
    extras=$(echo "$AGENT_EXTRAS" | jq --arg n "$slot_name" '.[$n] // {}')
    entry=$(echo "$entry $extras" | jq -s 'add')

    agents_json=$(echo "$agents_json" | jq --arg k "$slot_name" --argjson v "$entry" '. + {($k):$v}')
  done < <(echo "$TIER_DATA" | jq -r --arg t "$tier" '.[$t].agents | to_entries[] | .key + "=" + (.value | tojson)')

  if [ -n "$orchestrator_override" ]; then
    agents_json=$(echo "$agents_json" | jq --arg m "$orchestrator_override" '.sisyphus.model = $m')
  fi

  local categories_json
  categories_json='{}'
  while IFS='=' read -r cat_name cat_spec; do
    local logical_model
    logical_model=$(echo "$cat_spec" | jq -r 'if type=="string" then . else .model end')
    local variant_value
    variant_value=$(echo "$cat_spec" | jq -r 'if type=="object" and has("variant") then .variant else empty end')

    local resolved_model
    resolved_model=$(resolve_model "$logical_model" "$normalized_priority") || return 1

    local entry
    entry=$(jq -n --arg m "$resolved_model" '{model:$m}')
    if [ -n "$variant_value" ]; then
      entry=$(echo "$entry" | jq --arg v "$variant_value" '. + {variant:$v}')
    fi

    categories_json=$(echo "$categories_json" | jq --arg k "$cat_name" --argjson v "$entry" '. + {($k):$v}')
  done < <(echo "$TIER_DATA" | jq -r --arg t "$tier" '.[$t].categories | to_entries[] | .key + "=" + (.value | tojson)')

  local meta
  meta=$(jq -n \
    --arg tier "$tier" \
    --argjson priority "$priority_json" \
    --arg ts "$timestamp" \
    '{generated_by:"opencode-config",tier:$tier,priority:$priority,generated_at:$ts}')

  echo "$STATIC_CONFIG" | jq --argjson meta "$meta" --argjson agents "$agents_json" --argjson cats "$categories_json" \
    '. + {_meta:$meta, agents:$agents, categories:$cats}'
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

cmd_generate() {
  local project_flag=""
  local tier_flag=""
  local priority_flag=""
  local orchestrator_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project_flag="--project"; shift ;;
      --tier)
        [ $# -lt 2 ] && { echo "ERROR: --tier requires a value" >&2; return 1; }
        tier_flag="$2"
        shift 2
        ;;
      --priority)
        [ $# -lt 2 ] && { echo "ERROR: --priority requires a value" >&2; return 1; }
        priority_flag="$2"
        shift 2
        ;;
      --orchestrator)
        [ $# -lt 2 ] && { echo "ERROR: --orchestrator requires a value" >&2; return 1; }
        orchestrator_flag="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  local priority_csv=""
  if [ -n "$priority_flag" ]; then
    priority_csv=$(normalize_priority_csv "$priority_flag") || return 1
    save_providers "$priority_csv" || return 1
  else
    priority_csv=$(read_stored_providers) || return 1
    if [ -z "$priority_csv" ]; then
      echo "Select providers (Tab to multi-select, Enter to confirm):"
      local selected
      selected=$(echo "$PROVIDER_NAMES" | jq -r 'to_entries[] | .key + " — " + .value' | fzf --multi --prompt="Providers> " --height=40% --reverse || true)
      if [ -z "$selected" ]; then
        echo "ERROR: No providers selected" >&2
        return 1
      fi

      local provider_keys_json
      provider_keys_json=$(echo "$selected" | jq -R -s 'split("\n") | map(select(length > 0) | split(" — ")[0])')
      priority_csv=$(echo "$provider_keys_json" | jq -r 'join(",")')
      priority_csv=$(normalize_priority_csv "$priority_csv") || return 1
      save_providers "$priority_csv" || return 1
    fi
  fi

  local tier=""
  if [ -n "$tier_flag" ]; then
    tier="$tier_flag"
  else
    tier=$(printf '%s\n' \
      'balanced — Good defaults: Claude Opus orchestration, Codex coding' \
      'max — Strongest models across all roles' \
      'budget — Go tier economy (GLM-5, Kimi K2.5, MiniMax)' \
      | fzf --prompt="Tier> " --height=20% --reverse \
      | jq -R 'split(" — ")[0]' -r || true)
    if [ -z "$tier" ]; then
      echo "ERROR: No tier selected" >&2
      return 1
    fi
  fi

  local config_path
  config_path=$(get_config_path "$project_flag")

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

  echo "Generating config: tier=$tier, priority=$priority_csv"
  local config_json
  config_json=$(generate_config_json "$tier" "$priority_csv" "$orchestrator_flag") || return 1
  printf '%s\n' "$config_json" > "$config_path"

  echo "✓ Written to $config_path"
  echo
  echo "$config_json" | jq -r '
    "Tier:     " + ._meta.tier,
    "Priority: " + (._meta.priority | join(", ")),
    "",
    "Agents:",
    (.agents | to_entries | sort_by(.key) | .[] | "  " + .key + " → " + .value.model),
    "",
    "Categories:",
    (.categories | to_entries | sort_by(.key) | .[] | "  " + .key + " → " + .value.model)
  '
}

cmd_set() {
  local project_flag=""
  local priority_flag=""
  local tier_flag=""
  local agent_name=""
  local agent_model=""
  local category_name=""
  local category_model=""
  local variant_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project_flag="--project"; shift ;;
      --priority)
        [ $# -lt 2 ] && { echo "ERROR: --priority requires a value" >&2; return 1; }
        priority_flag="$2"
        shift 2
        ;;
      --tier)
        [ $# -lt 2 ] && { echo "ERROR: --tier requires a value" >&2; return 1; }
        tier_flag="$2"
        shift 2
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
      --variant)
        [ $# -lt 2 ] && { echo "ERROR: --variant requires a value" >&2; return 1; }
        variant_flag="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  if [ -n "$agent_name" ] && [ -n "$category_name" ]; then
    echo "ERROR: Use either --agent or --category, not both" >&2
    return 1
  fi

  local config_path
  config_path=$(get_config_path "$project_flag")

  if [ ! -f "$config_path" ]; then
    echo "ERROR: No config found at $config_path. Run 'opencode-config generate' first." >&2
    return 1
  fi

  local current
  current=$(<"$config_path")

  if [ -n "$agent_name" ]; then
    if ! echo "$current" | jq -e --arg n "$agent_name" '.agents[$n]' >/dev/null 2>&1; then
      echo "ERROR: Invalid agent name '$agent_name'" >&2
      echo "Valid agents: $(echo "$current" | jq -r '.agents | keys | join(", ")')" >&2
      return 1
    fi
    local updated
    updated=$(echo "$current" | jq --arg n "$agent_name" --arg m "$agent_model" '.agents[$n].model = $m')
    if [ -n "$variant_flag" ]; then
      updated=$(echo "$updated" | jq --arg n "$agent_name" --arg v "$variant_flag" '.agents[$n].variant = $v')
    fi
    printf '%s\n' "$updated" > "$config_path"
    echo "✓ Updated agent '$agent_name' → $agent_model${variant_flag:+ (variant: $variant_flag)}"
    return 0
  fi

  if [ -n "$category_name" ]; then
    if ! echo "$current" | jq -e --arg n "$category_name" '.categories[$n]' >/dev/null 2>&1; then
      echo "ERROR: Invalid category name '$category_name'" >&2
      echo "Valid categories: $(echo "$current" | jq -r '.categories | keys | join(", ")')" >&2
      return 1
    fi
    local updated
    updated=$(echo "$current" | jq --arg n "$category_name" --arg m "$category_model" '.categories[$n].model = $m')
    if [ -n "$variant_flag" ]; then
      updated=$(echo "$updated" | jq --arg n "$category_name" --arg v "$variant_flag" '.categories[$n].variant = $v')
    fi
    printf '%s\n' "$updated" > "$config_path"
    echo "✓ Updated category '$category_name' → $category_model${variant_flag:+ (variant: $variant_flag)}"
    return 0
  fi

  local current_tier
  current_tier=$(echo "$current" | jq -r '._meta.tier // "balanced"')

  local current_priority
  current_priority=$(echo "$current" | jq -r '._meta.priority // empty | join(",")')
  if [ -z "$current_priority" ]; then
    current_priority=$(read_stored_providers) || return 1
  fi

  local tier="${tier_flag:-$current_tier}"
  local priority_csv="${priority_flag:-$current_priority}"
  if [ -z "$priority_csv" ]; then
    echo "ERROR: Empty priority. Run 'opencode-config generate' first or use --priority" >&2
    return 1
  fi
  priority_csv=$(normalize_priority_csv "$priority_csv") || return 1

  echo "Re-generating: tier=$tier, priority=$priority_csv"
  local config_json
  config_json=$(generate_config_json "$tier" "$priority_csv") || return 1
  printf '%s\n' "$config_json" > "$config_path"

  if [ -n "$priority_flag" ]; then
    save_providers "$priority_csv" || return 1
  fi

  echo "✓ Updated config (tier=$tier, priority=$priority_csv)"
}

cmd_show() {
  local project_flag="${1:-}"
  local user_config="$OC_CONFIG_FILE"
  local project_config=".opencode/oh-my-opencode.json"

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

  local config
  config=$(<"$effective_config")
  if ! echo "$config" | jq -e '.' >/dev/null 2>&1; then
    echo "ERROR: Config at $effective_config is not valid JSON" >&2
    return 1
  fi

  local tier
  tier=$(echo "$config" | jq -r '._meta.tier // "unknown"')
  local priority
  priority=$(echo "$config" | jq -r '._meta.priority // [] | join(", ")')

  echo "Scope:    $scope ($(realpath "$effective_config" 2>/dev/null || echo "$effective_config"))"
  echo "Tier:     $tier"
  echo "Priority: ${priority:-unknown}"
  echo

  printf "%-28s %-44s %s\n" "Agent" "Model" "Variant"
  printf "%-28s %-44s %s\n" "────────────────────────────" "────────────────────────────────────────────" "───────"
  echo "$config" | jq -r '.agents | to_entries | sort_by(.key) | .[] | [.key, .value.model, (.value.variant // "-")] | @tsv' | while IFS=$'\t' read -r name model variant; do
    printf "%-28s %-44s %s\n" "$name" "$model" "$variant"
  done

  echo
  printf "%-28s %-44s %s\n" "Category" "Model" "Variant"
  printf "%-28s %-44s %s\n" "────────────────────────────" "────────────────────────────────────────────" "───────"
  echo "$config" | jq -r '.categories | to_entries | sort_by(.key) | .[] | [.key, .value.model, (.value.variant // "-")] | @tsv' | while IFS=$'\t' read -r name model variant; do
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
        echo "No stored providers. Run 'opencode-config providers set copilot,openai,google,opencode-go,opencode'"
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
      save_providers "$csv" || return 1
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
      echo "Usage: opencode-config providers {list|set|add|remove}" >&2
      return 1
      ;;
  esac
}

usage() {
  cat <<'EOF'
opencode-config — oh-my-opencode.json generator

Usage:
  opencode-config generate [--tier TIER] [--priority P1,P2,...] [--orchestrator MODEL] [--project]
  opencode-config set (--priority P1,P2,... | --tier TIER | --agent NAME MODEL | --category NAME MODEL) [--variant V] [--project]
  opencode-config show [--project]
  opencode-config providers {list|set P1,P2,...|add P|remove P}

Tiers:     balanced, max, budget
Providers: copilot, openai, google, opencode-go, opencode
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
