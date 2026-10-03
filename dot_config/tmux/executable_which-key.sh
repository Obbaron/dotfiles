#!/usr/bin/env bash
# Usage: which-key.sh <client-name>
client="$1"
sep=$'\x1f'

# tmux treats an argument ending in ';' as a command separator; escape it
esc() { local s="$1"; [[ "$s" == *';' ]] && s="${s%;}\\;"; printf '%s' "$s"; }

args=()
while IFS="$sep" read -r key note cmd; do
  [[ "$note" == wk:* ]] || continue
  note="${note#wk:}"
  [ "$key" = "Space" ] && continue
  # Only single-character keys are used as menu shortcuts
  if [ "${#key}" -eq 1 ]; then shortcut="$(esc "$key")"; else shortcut=""; fi
  args+=("$(esc "$note  ($key)")" "$shortcut" "$(esc "$cmd")")
done < <(tmux list-keys -T prefix -F "#{key_string}${sep}#{key_note}${sep}#{key_command}")

if [ ${#args[@]} -eq 0 ]; then
  tmux display-message -c "$client" "which-key: no bindings with wk: notes"
  exit 0
fi

err=$(tmux display-menu -c "$client" -T " Keys " -x C -y C "${args[@]}" 2>&1) \
  || tmux display-message -c "$client" "which-key: ${err:-display-menu failed}"
