#!/usr/bin/env bash
# Session switcher for a tmux popup
#   Enter          switch to selected session
#   Ctrl+x         kill selected session
#   Esc            close

# for fzf to rebuild the list
if [ "${1:-}" = "--list" ]; then
  tmux list-sessions -F '#{session_name}' | grep -vxF -- "$CURRENT_SESSION"
  exit 0
fi

export CURRENT_SESSION
CURRENT_SESSION=$(tmux display-message -p '#S')

choice=$(
  "$0" --list | fzf --reverse --prompt 'session> ' \
    --header 'enter: switch   ctrl-x: kill   esc: close' \
    --bind "ctrl-x:execute-silent(tmux kill-session -t ={})+reload('$0' --list)"
) || exit 0

[ -n "$choice" ] && tmux switch-client -t "=$choice"
