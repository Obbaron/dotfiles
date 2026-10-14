# ~/.bashrc.d/desktop.sh
# desktop integration

# copy: stdin -> clipboard
if have wl-copy || have xclip || have pbcopy || have clip.exe; then
    copy() {
        if   have wl-copy;  then wl-copy
        elif have xclip;    then xclip -selection clipboard
        elif have pbcopy;   then pbcopy
        else clip.exe
        fi
    }
fi

have xdg-open && alias open='xdg-open'
