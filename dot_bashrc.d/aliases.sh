# aliases.sh
# sourced by ~/.bashrc via ~/.bashrc.d/

[[ $- != *i* ]] && return

alias config="$EDITOR ~/.bashrc"
alias aliases="$EDITOR ~/.bashrc.d/aliases.sh"
alias functions="$EDITOR ~/.bashrc.d/functions.sh"

alias reload='source ~/.bashrc'

alias dir="dir --color=auto"
alias vdir="vdir --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias hl='rg --passthru'
alias jctl="journalctl -p 3 -xb"
alias psmem="ps auxf | sort -nr -k 4"
alias psmem10="ps auxf | sort -nr -k 4 | head -10"
alias h='history'
alias hg='history | grep'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias lg='lazygit'
alias cm='chezmoi'

grep --color=auto < /dev/null &>/dev/null &&
    alias grep='grep --color=auto'
command -v xdg-open &>/dev/null &&
    alias open='xdg-open'

if command -v eza >/dev/null 2>&1; then
  alias ls="eza -al --color=always --group-directories-first --icons"
  alias la="eza -a  --color=always --group-directories-first --icons"
  alias ll="eza -l  --color=always --group-directories-first --icons"
  alias lt="eza -at --color=always --group-directories-first --icons"
  alias l.="eza -a | grep -e '^\.'"
else
  alias ls="ls --color=auto"
  alias la="ls -A"
  alias ll="ls -alF"
  alias lt="ls -altr"
  alias l.="ls -A | grep '^\.'"
fi

# git
alias nb='git checkout -b "$USER-$(date +%s)"' # new branch
alias ga='git add . --all'
alias gb='git branch'
alias gc='git clone'
alias gci='git commit -a'
alias gco='git checkout'
alias gd="git diff ':!*lock'"
alias gdf='git diff' # git diff (full)
alias gi='git init'
alias gl='git log'
alias gp='git push origin HEAD'
alias gr='git rev-parse --show-toplevel' # git root
alias gs='git status'
alias gt='git tag'
alias gu='git pull'

alias b='btop'
alias ff='fastfetch'
alias c='clear'
alias q='exit'
alias wget="wget -c"

alias ipkg='install_pkg'
alias upkg='update_pkg'

alias bigboi="ssh guggoo@BigBoi"

# spelling is hard
alias suod='sudo'
alias chomd='chmod'
alias gerp='grep'
alias chomd='chmod'
