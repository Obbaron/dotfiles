# ~/.bashrc.d/git.sh

have git || return 0

alias nb='git checkout -b "$USER-$(date +%s)"'  # new branch
alias ga='git add . --all'
alias gb='git branch'
alias gc='git clone'
alias gci='git commit -a'
alias gco='git checkout'
alias gd="git diff ':!*lock'"                   # diff, ignoring lockfiles
alias gdf='git diff'                            # diff (full)
alias gi='git init'
alias gl='git log'
alias gp='git push origin HEAD'
alias gr='git rev-parse --show-toplevel'        # git root
alias gs='git status'
alias gt='git tag'
alias gu='git pull'

have lazygit && alias lg='lazygit'
