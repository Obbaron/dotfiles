#!/usr/bin/env bash
# Push fzf's theme into tmux's global environment

mode="${1:-local}"
noctalia="$HOME/.config/fzf/themes/noctalia.sh"

if [ "$mode" = local ] && [ -r "$noctalia" ]; then
  opts=$(env -u FZF_DEFAULT_OPTS bash -c '. "$1"; printf %s "$FZF_DEFAULT_OPTS"' _ "$noctalia")
  tmux set-environment -g FZF_DEFAULT_OPTS "$opts"
else
  tmux source-file -q "$(tmux show -gqv @tmux_config)/themes/fzf.conf"
fi
