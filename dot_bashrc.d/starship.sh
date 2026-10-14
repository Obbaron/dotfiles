# ~/.bashrc.d/starship.sh
# This must run last!

have starship || return 0

eval "$(starship init bash)"
