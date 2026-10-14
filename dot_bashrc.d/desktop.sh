# ~/.bashrc.d/desktop.sh
# desktop integration

# copy: stdin -> clipboard
if _have wl-copy || _have xclip || _have pbcopy || _have clip.exe; then
    copy() {
        if   _have wl-copy;  then wl-copy
        elif _have xclip;    then xclip -selection clipboard
        elif _have pbcopy;   then pbcopy
        else clip.exe
        fi
    }
fi

_have xdg-open && alias open='xdg-open'
