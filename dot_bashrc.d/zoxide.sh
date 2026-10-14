# ~/.bashrc.d/zoxide.sh

_have zoxide || return 0

eval "$(zoxide init bash --cmd cd)"

# Ctrl-F: fuzzy-jump to a recent directory
_have fzf && bind '"\C-f":"cdi\n"'
