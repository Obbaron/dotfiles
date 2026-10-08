#!/usr/bin/env bash
# keybind list for a tmux popup (fzf)

export LC_ALL=C.UTF-8

RUN_ON_ENTER="${RUN_ON_ENTER:-1}"
S=$'\x1f'
FMT="#{key_table}${S}#{key_string}${S}#{key_note}${S}#{key_command}"

pretty_key() {
  local k="$1"
  [[ ${#k} -eq 2 && $k == \\* ]] && k="${k:1}"   # tmux escapes $ " ; and \
  [ "$k" = BTab ] && k="S-Tab"
  printf '%s' "$k"
}

# preview pane
if [ "${1:-}" = "--preview" ]; then
  table="$2"; key="$3"; cmd="$4"; note="$5"
  printf 'Key      %s' "$(pretty_key "$key")"
  case "$table" in
    prefix) printf '   (after the prefix, %s)\n' "$(tmux show -gqv prefix)" ;;
    root)   printf '   (no prefix needed)\n' ;;
    *)      printf '   (inside %s)\n' "$table" ;;
  esac
  [ -n "$note" ] && printf 'Note     %s\n' "${note#wk:}"
  printf 'Command  %s\n' "$cmd"
  exit 0
fi

# build list
client="${1:-$(tmux display-message -p '#{client_name}')}"

declare -A stock
sock="kb$$"
while IFS="$S" read -r t k _ c; do stock["$t|$k"]="$c"; done < <(
  env -u TMUX tmux -L "$sock" -f /dev/null new-session -d -s x \; list-keys -F "$FMT" 2>/dev/null
  env -u TMUX tmux -L "$sock" kill-server 2>/dev/null)

lines=()
while IFS="$S" read -r table key note cmd; do
  case "$table" in
    prefix)       trank=0; label=prefix ;;
    root)         trank=1; label=root ;;
    copy-mode-vi) trank=2; label=copy ;;
    *)            continue ;;
  esac
  rank=1; mark=" "  # 1 = tmux default, 0 = user
  if [ "${stock["$table|$key"]-}" != "$cmd" ]; then rank=0; mark=$'\e[35m●\e[0m'; fi
  
  [ "$table" = root ] && [ $rank -eq 1 ] && continue

  desc="${note#wk:}"
  [ -z "$desc" ] && { desc="${cmd%% *}"; desc="${desc//-/ }"; }
  show="$(printf '%s \e[2m%-6s\e[0m \e[1m%-12.12s\e[0m %-34.34s \e[2m%s\e[0m' \
          "$mark" "$label" "$(pretty_key "$key")" "$desc" "$cmd")"
  
  lines+=("${rank}${trank}"$'\t'"${show}"$'\t'"${table}"$'\t'"${key}"$'\t'"${cmd}"$'\t'"${note}")
done < <(tmux list-keys -F "$FMT")

# print the list instead of fzf (for debug)
if [ "${KB_LIST_ONLY:-}" ]; then
  printf '%s\n' "${lines[@]}" | sort -s -t$'\t' -k1,1 | cut -f2-
  exit 0
fi

selection=$(
  printf '%s\n' "${lines[@]}" | sort -s -t$'\t' -k1,1 | cut -f2- |
  fzf --reverse --ansi --prompt 'keys> ' --delimiter=$'\t' --with-nth=1 \
      --header "$( [ "$RUN_ON_ENTER" = 1 ] && echo 'enter: run   esc: close   ●: yours' || echo 'esc: close   ●: yours' )" \
      --preview "'$0' --preview {2} {3} {4} {5}" --preview-window 'down,25%,wrap,border-top'
) || exit 0

# map bindings
[ "$RUN_ON_ENTER" = 1 ] || exit 0
IFS=$'\t' read -r _ table key _ <<<"$selection"
case "$table" in
  prefix) keys=("$(tmux show -gqv prefix)" "$key") ;;
  root)   keys=("$key") ;;
  *)      exit 0 ;;
esac

# semicolon escape guard
for i in "${!keys[@]}"; do
  [[ ${keys[i]} == *\; ]] && keys[i]="${keys[i]%;}\\;"
done

cmd="$(printf '%q ' tmux send-keys -K -c "$client" "${keys[@]}")"

tmux run-shell -b "sleep 0.25; ${cmd//#/##}"
