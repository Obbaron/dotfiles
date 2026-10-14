# ~/.bashrc.d/zoxide.sh

have zoxide || return 0

eval "$(zoxide init bash --cmd cd)"

# Ctrl-F: fuzzy-jump to a recent directory
have fzf && bind '"\C-f":"cdi\n"'
