# ~/.bashrc.d/editor.sh

if   _have nvim; then export EDITOR=nvim
elif _have vim;  then export EDITOR=vim
else return 0
fi

export VISUAL="$EDITOR"
