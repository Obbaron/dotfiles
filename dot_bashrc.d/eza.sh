# ~/.bashrc.d/eza.sh
# overrides ls aliases in ~/.bashrc

have eza || return 0

_ls='eza --color=auto --group-directories-first --icons'
alias ls="$_ls -al"
alias la="$_ls -a"
alias ll="$_ls -l"
alias lt="$_ls -al --sort=modified"
unset _ls
