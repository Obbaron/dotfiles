# ~/.bashrc.d/starship.sh
# This must run last!

_have starship || return 0

eval "$(starship init bash)"
