# ~/.bashrc.d/editor.sh

if   have nvim; then export EDITOR=nvim
elif have vim;  then export EDITOR=vim
else return 0
fi

export VISUAL="$EDITOR"
