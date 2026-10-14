# ~/.bashrc.d/fzf.sh

_have fzf || return 0

# fzf directories under the current one and cd
f() {
    local dir status

    dir=$(find . -type d | fzf)
    status=$?

    if [ "$status" -eq 130 ]; then
        echo "Cancelled" >&2
        return 130
    elif [ "$status" -ne 0 ]; then
        echo "Error: fzf failed" >&2
        return "$status"
    fi

    [ -z "$dir" ] && {
        echo "No directory selected" >&2
        return 1
    }

    cd -- "$dir" || return
}
