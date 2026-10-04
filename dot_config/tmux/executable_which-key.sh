#!/usr/bin/env bash
# Usage: which-key.sh <client-name>
client="$1"
sep=$'\x1f'

WIDTH="${WK_WIDTH:-36}"

# tmux treats an argument ending in ';' as a command separator
esc() { local s="$1"; [[ "$s" == *';' ]] && s="${s%;}\\;"; printf '%s' "$s"; }

args=()
while IFS="$sep" read -r key note cmd; do
  [[ "$note" == wk:* ]] || continue
  note="${note#wk:}"
  [ "$key" = "Space" ] && continue

  if [ "${#key}" -eq 1 ]; then
    # tmux appends "(key)" itself for shortcut items
    shortcut="$(esc "$key")"
    label=$(printf '  %-*s' "$WIDTH" "$note")
  else
    # no shortcut possible, so show the key in the label
    shortcut=""
    label=$(printf '  %-*s(%s)' "$WIDTH" "$note" "$key")
  fi
  args+=("$(esc "$label")" "$shortcut" "$(esc "$cmd")")
done < <(tmux list-keys -T prefix -F "#{key_string}${sep}#{key_note}${sep}#{key_command}")

if [ ${#args[@]} -eq 0 ]; then
  tmux display-message -c "$client" "which-key: no bindings with wk: notes"
  exit 0
fi

err=$(tmux display-menu -c "$client" -T " Keys " -x R -y B -- "${args[@]}" 2>&1) \
  || tmux display-message -c "$client" "which-key: ${err:-display-menu failed}"
