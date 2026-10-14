# ~/.bashrc.d/starship.sh
# This must run last!

_have starship || return 0

# Drop the base prompt builder so _precmd (in ~/.bashrc) leaves PS1 to starship.
unset -f _prompt 2>/dev/null

eval "$(starship init bash)"
