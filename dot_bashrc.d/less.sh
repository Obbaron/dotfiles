# ~/.bashrc.d/less.sh

_have less || return 0

export PAGER="less"
export LESS="-R --mouse"

export LESS_TERMCAP_mb=$'\e[1;31m'      # begin blink
export LESS_TERMCAP_md=$'\e[1;31m'      # begin bold
export LESS_TERMCAP_me=$'\e[0m'         # end bold/blink
export LESS_TERMCAP_so=$'\e[1;33;44m'   # begin standout (status line, search hits)
export LESS_TERMCAP_se=$'\e[0m'         # end standout
export LESS_TERMCAP_us=$'\e[4;1;32m'    # begin underline
export LESS_TERMCAP_ue=$'\e[0m'         # end underline
export LESS_TERMCAP_mr=$'\e[7m'         # begin reverse
export LESS_TERMCAP_mh=$'\e[2m'         # begin dim
export LESS_TERMCAP_ZN=$'\e[74m'        # begin subscript
export LESS_TERMCAP_ZV=$'\e[75m'        # end subscript
export LESS_TERMCAP_ZO=$'\e[73m'        # begin superscript
export LESS_TERMCAP_ZW=$'\e[75m'        # end superscript
