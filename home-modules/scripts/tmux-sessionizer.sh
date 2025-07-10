#!/usr/bin/env bash

static_dirs=(
    "$HOME/.config/nvim/"
    "$HOME/"
    "$HOME/tmp/"
    "$HOME/4Vault/"
)

if [[ $# -eq 1 ]]; then
    selected=$1
else
    selected=$(
        {
            printf "%s\n" "${static_dirs[@]}"
            find "$HOME/projects" -mindepth 1 -maxdepth 1 -type d
        } | fzf
    )
fi

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    tmux new-session -s "$selected_name" -c "$selected"
    exit 0
fi

if ! tmux has-session -t="$selected_name" 2>/dev/null; then
    tmux new-session -ds "$selected_name" -c "$selected"
fi

tmux switch-client -t "$selected_name"
