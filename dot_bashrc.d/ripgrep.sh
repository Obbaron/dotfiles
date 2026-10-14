# ~/.bashrc.d/ripgrep.sh

have rg || return 0

hl() { rg --passthru "$@"; }
