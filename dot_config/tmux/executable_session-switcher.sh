#!/usr/bin/env bash
# Session switcher for a tmux popup
#   Enter          switch to highlighted session
#   Enter          text has no match: create session and switch
#   Ctrl+x         kill highlighted session
#   Esc            close

# rebuild list after kill
if [ "${1:-}" = "--list" ]; then
  tmux list-sessions -F '#{session_name}' | grep -vxF -- "$CURRENT_SESSION"
  exit 0
fi

export CURRENT_SESSION
CURRENT_SESSION=$(tmux display-message -p '#S')

out=$(
  "$0" --list | fzf --reverse --print-query --prompt 'session> ' \
    --header 'enter: switch/create   ctrl-x: kill   esc: close' \
    --bind "ctrl-x:execute-silent(tmux kill-session -t ={})+reload('$0' --list)"
)
rc=$?

# 0 = picked match, 1 = typed text matched nothing
[ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || exit 0

query=$(sed -n 1p <<<"$out")
match=$(sed -n 2p <<<"$out")

if [ -n "$match" ]; then
  tmux switch-client -t "=$match"
elif [ -n "$query" ]; then
  name="${query//[.:]/_}"  # tmux turns '.' and ':' in session names into '_'
  tmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name" -c ~
  tmux switch-client -t "=$name"
fi
