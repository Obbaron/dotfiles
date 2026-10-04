#!/usr/bin/env bash
# Cheat sheet of keybinds for tmux popup
set -u

# Layout
KW=11      # width of the key "keycap" column
DW=26      # width of the description column
GAP=4      # spaces between columns
MAXCOLS=3  # never use more than this many columns
BW=$((KW + 1 + DW))

# Colors (Noctalia palette, Mocha fallbacks)
opt() { local v; v=$(tmux show -gqv "$1" 2>/dev/null); printf '%s' "${v:-$2}"; }
rgb() { local h="${1#\#}"; printf '%d;%d;%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
sgr() { printf '\e[%sm' "$1"; }

C_HEAD=$(sgr "1;38;2;$(rgb "$(opt @noctalia_primary '#cba6f7')")")
C_KEY=$(sgr "1;48;2;$(rgb "$(opt @noctalia_surface_container_high '#45475a')");38;2;$(rgb "$(opt @noctalia_on_surface '#cdd6f4')")")
C_DESC=$(sgr "38;2;$(rgb "$(opt @noctalia_on_surface_variant '#a6adc8')")")
C_DIM=$(sgr "38;2;$(rgb "$(opt @noctalia_outline '#6c7086')")")
RESET=$'\e[0m'

pfx=$(tmux show -gqv prefix); pfx="${pfx:-C-b}"

#  block builders
printf -v RULE '%*s' "$BW" ''; RULE=${RULE// /─}
blocks=(); cur=""

flush() { [ -n "$cur" ] && blocks+=("$cur"$'\n'); cur=""; }

sec() {
  flush
  local t; printf -v t '%-*s' "$BW" "$1"
  cur="${C_HEAD}${t}${RESET}"$'\n'"${C_DIM}${RULE}${RESET}"
}

row() {
  local k d
  printf -v k ' %-*s ' $((KW - 2)) "$1"
  printf -v d '%-*s' "$DW" "$2"
  cur+=$'\n'"${C_KEY}${k}${RESET} ${C_DESC}${d}${RESET}"
}

### === CONTENT: === ###
sec "Panes"
row "h j k l"   "Focus pane"
row "C-h/j/k/l" "Focus pane (no prefix)"
row "/"         "Split right"
row "-"         "Split below"
row "m"         "Zoom pane"
row "x"         "Kill pane"
row "Arrows"    "Resize pane (repeats)"
row "o"         "Next pane"
row "q"         "Show pane numbers"
row "{  }"      "Swap pane up / down"
row "!"         "Break pane to window"

sec "Windows"
row "Tab"       "Last window"
row "S-Tab"     "New window"
row "c"         "New window"
row "1 - 9"     "Go to window"
row "n  p"      "Next / previous window"
row ","         "Rename window"
row "&"         "Kill window"
row "w"         "Window / session tree"
row "f"         "Find window"

sec "Sessions"
row "C-n"       "New session"
row "C-o"       "Switch session (fzf)"
row "s"         "Session tree"
row "\$"        "Rename session"
row "(  )"      "Previous / next session"
row "L"         "Last session"
row "d"         "Detach"

sec "Tools"
row "C-g"       "Lazygit"
row "C-y"       "Yazi"
row "C-t"       "Shell popup"
row "Space"     "This cheat sheet"
row "r"         "Reload config"
row ":"         "Command prompt"
row "?"         "List all bindings"
row "I  U"      "Install / update plugins"

sec "Copy mode (vi)"
row "["         "Enter copy mode"
row "v"         "Begin selection"
row "y"         "Copy and exit"
row "/  ?"      "Search forward / back"
row "n  N"      "Next / previous match"
row "g  G"      "Top / bottom"
row "C-u C-d"   "Half page up / down"
row "q"         "Quit copy mode"
row "]"         "Paste buffer"

sec "Mouse"
row "Click"     "Focus pane / window tab"
row "Drag"      "Select text / resize border"
row "Scroll"    "Enter copy mode and scroll"
flush
### === end of content == ###

# layout engine
W=$(tput cols); H=$(tput lines)
ncols=$(( (W - 4 + GAP) / (BW + GAP) ))
(( ncols > MAXCOLS )) && ncols=$MAXCOLS
(( ncols < 1 )) && ncols=1

declare -A cell; declare -a colh
for ((c = 0; c < ncols; c++)); do colh[c]=0; done

for blk in "${blocks[@]}"; do
  mapfile -t lines <<<"$blk"
  best=0
  for ((c = 1; c < ncols; c++)); do (( colh[c] < colh[best] )) && best=$c; done
  for ln in "${lines[@]}"; do
    cell[$best,${colh[best]}]="$ln"
    colh[best]=$(( colh[best] + 1 ))
  done
done

maxh=0
for ((c = 0; c < ncols; c++)); do (( colh[c] > maxh )) && maxh=${colh[c]}; done

printf -v GAPSTR '%*s' "$GAP" ''
printf -v BLANK '%*s' "$BW" ''

out=()
out+=("")
out+=("  ${C_HEAD}Keybinds${RESET}   ${C_DIM}prefix is ${pfx}. Keys need the prefix unless marked.${RESET}")
out+=("")
for ((r = 0; r < maxh; r++)); do
  line="  "
  for ((c = 0; c < ncols; c++)); do
    cellv="${cell[$c,$r]-}"
    [ -z "$cellv" ] && cellv="$BLANK"
    line+="$cellv"
    (( c < ncols - 1 )) && line+="$GAPSTR"
  done
  out+=("$line")
done

if (( ${#out[@]} + 1 > H )); then
  out+=("  ${C_DIM}j/k to scroll, q to close${RESET}")
  printf '%s\n' "${out[@]}" | less -R
else
  out+=("  ${C_DIM}press any key to close${RESET}")
  printf '%s\n' "${out[@]}"
  read -rsn1 _
fi
