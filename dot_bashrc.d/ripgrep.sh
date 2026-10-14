# ~/.bashrc.d/ripgrep.sh

have rg || return 0

unalias hl 2>/dev/null
hl() { rg --passthru "$@"; }
