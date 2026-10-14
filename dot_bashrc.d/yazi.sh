# ~/.bashrc.d/yazi.sh
# y: run yazi and cd

_have yazi || return 0

y() {
    local tmp cwd
    tmp=$(mktemp -t "yazi-cwd.XXXXXX")
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}
