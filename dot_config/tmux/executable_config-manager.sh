#!/usr/bin/env bash
# Config manager tmux popup

set -u

stty -ixon 2>/dev/null  # ctrl-s freezes popup unless flow control is off

SRC="${CM_SRC:-$(chezmoi source-path)}"
export CM_SRC="$SRC"

# Chezmoi's special files (prefixed with @)
list() {
  chezmoi managed --include=files
  (cd "$SRC" && find . -maxdepth 2 -type f \( -path './.chezmoi*' -o -path './run_*' \) \
    -printf '@%P\n' | sort)
}

preview() {
  local f="$1" p
  [ -z "$f" ] && return
  
  if [[ $f == @* ]]; then p="$SRC/${f#@}"; else p="$HOME/$f"; fi
  if command -v bat >/dev/null 2>&1; then
    bat --color=always --style=numbers --paging=never -- "$p" 2>&1
  else
    cat -- "$p" 2>&1
  fi
}

pause() { printf '\n\e[2m[ press any key ]\e[0m'; read -rsn1; }

act() {
  local rc=0
  case "$1" in
    apply)   chezmoi apply || rc=$? ;;
    diff)    chezmoi diff --pager 'less -R'; return ;;
    status)  { chezmoi status; echo; chezmoi git -- status -sb; } || rc=$? ;;
    update)  chezmoi update || rc=$? ;;
    push)    chezmoi push || rc=$? ;;
    lazygit) (cd "$SRC" && lazygit); return ;;
  esac
  (( rc )) && printf '\n\e[31mfailed (exit %d)\e[0m\n' "$rc"
  pause
}

# fzf subcommands
case "${1:-}" in
  --list)    list; exit 0 ;;
  --preview) preview "${2:-}"; exit 0 ;;
  --act)     exec >/dev/tty 2>&1; act "${2:-}"; exit 0 ;;
esac

self="$0"
reload="reload('$self' --list)"

choice=$(
  list | fzf --reverse --prompt 'config> ' --query "$*" \
    --header $'enter: edit   ctrl-a: apply   ctrl-d: diff   ctrl-s: status\nctrl-u: update   ctrl-p: push   ctrl-g: lazygit   esc: close' \
    --preview "'$self' --preview {}" \
    --preview-window 'right,55%,wrap,<90(hidden)' \
    --bind "ctrl-a:execute('$self' --act apply)+$reload" \
    --bind "ctrl-d:execute('$self' --act diff)+$reload" \
    --bind "ctrl-s:execute('$self' --act status)+$reload" \
    --bind "ctrl-u:execute('$self' --act update)+$reload" \
    --bind "ctrl-p:execute('$self' --act push)+$reload" \
    --bind "ctrl-g:execute('$self' --act lazygit)+$reload"
) || exit 0

[ -n "$choice" ] || exit 0

if [[ $choice == @* ]]; then
  "${EDITOR:-nvim}" "$SRC/${choice#@}"
else
  chezmoi edit --apply "$HOME/$choice"
fi
