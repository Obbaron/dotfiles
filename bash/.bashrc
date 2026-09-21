# .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='\[\e[32m\]\u\[\e[2;32m\]@\h\[\e[0m\]:\[\e[32m\]\w\[\e[0m\]\$ '

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# History
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize
shopt -s cdspell

# Env vars, aliases, and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init bash --cmd cd)"
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
