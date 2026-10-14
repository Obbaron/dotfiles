# ~/.bashrc.d/ripgrep.sh

_have rg || return 0

hl() { rg --passthru "$@"; }
