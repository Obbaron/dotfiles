# ~/.bashrc.d/tmux.sh
# Auto-start / re-attach to tmux session
# Skip with: BASHRC_SKIP=tmux bash -i
#
# This module must load last!!

_have tmux || return 0
[ -z "${TMUX-}" ] || return 0

tmux new-session -A -s default
