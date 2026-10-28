# ~/.bashrc.d/git.sh

_have git || return 0

alias nb='git checkout -b "$USER-$(date +%s)"'  # new branch
alias ga='git add . --all'
alias gc='git commit -a'
alias gp='git pull'
alias gP='git push origin HEAD'
alias gb='git branch'
alias gcl='git clone'
alias gco='git checkout'
alias gd="git diff ':!*lock'"                   # diff, ignoring lockfiles
alias gdf='git diff'                            # diff (full)
alias gi='git init'
alias gl='git log'
alias gr='git rev-parse --show-toplevel'        # git root
alias gs='git status'
alias gt='git tag'

_have lazygit && alias lg='lazygit'
