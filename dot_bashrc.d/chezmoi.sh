# ~/.bashrc.d/chezmoi.sh

_have chezmoi || return 0

alias cm='chezmoi'

brc() {
    local file="$HOME/.bashrc" confirm
    [ -n "$1" ] && file="$HOME/.bashrc.d/${1%.sh}.sh"

    if ! chezmoi source-path "$file" >/dev/null 2>&1; then
        echo "brc: $file is not managed by chezmoi."
        read -r -p "Add it to chezmoi? (y/N): " confirm
        case $confirm in
            [yY]|[yY][eE][sS]) ;;
            *) return 1 ;;
        esac
        # seed new files
        [ -e "$file" ] || printf '# ~%s\n' "${file#"$HOME"}" > "$file" || return
        chezmoi add "$file" || return
    fi

    chezmoi edit --apply "$file"
}

have fzf || return 0

# cfg <query>: pick a managed file, edit it, apply changes
cfg() {
    local src choice item
    src=$(chezmoi source-path) || return
    choice=$(
        {
            chezmoi managed --include=files
            for item in "$src"/.chezmoi* "$src"/run_*; do
                [ -e "$item" ] && echo "@${item##*/}"
            done
        } | fzf --prompt='config> ' --query="$*" --select-1 \
                --preview "f={}; if [[ \$f == @* ]]; then cat '$src'/\${f#@}; else cat ~/\$f; fi"
    ) || return
    if [[ $choice == @* ]]; then
        "${EDITOR:-vi}" "$src/${choice#@}"
    else
        chezmoi edit --apply "$HOME/$choice"
    fi
}
