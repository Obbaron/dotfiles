# ~/.bashrc.d/00-env.sh

# Prefer neovim (its own role); fall back to vim, whose config this role ships.
if command -v nvim >/dev/null 2>&1; then
    export EDITOR="nvim"
else
    export EDITOR="vim"
fi
export VISUAL="$EDITOR"

export PAGER="less"
export LESS="-R --mouse"
export LANG="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"
export GPG_TTY=$(tty)
[ -d "$HOME/bin" ]        && export PATH="$HOME/bin:$PATH"
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
