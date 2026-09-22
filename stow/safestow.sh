#!/bin/sh

set -eu

: "${HOME:?HOME must be set}"
repo="${DOTFILES_DIR:-$HOME/.dotfiles}"
target="${STOW_TARGET:-$HOME}"
assume_yes="${STOW_ASSUME_YES:-0}"

# Warn on abort mid-backup. warn from signal handlers directly
mutating=0
warned=0
warn_if_dirty() {
    [ "$warned" = 1 ] && return 0
    warned=1
    if [ "$mutating" = 1 ]; then
        echo "safestow.sh: aborted after backups began; .bak files may exist and stowing may be incomplete." >&2
    fi
    return 0
}
trap 'warn_if_dirty' EXIT
trap 'warn_if_dirty; exit 130' INT
trap 'warn_if_dirty; exit 143' TERM

if [ ! -d "$repo" ]; then
    echo "stow directory not found: $repo" >&2
    exit 1
fi


set +e
output=$(stow --no --dir="$repo" --target="$target" "$@" 2>&1)
status=$?
set -e

[ -n "$output" ] && printf '%s\n' "$output"

conflicts=$(
    printf '%s\n' "$output" | awk '
        match($0, /existing target is neither a link nor a directory: /) ||
        match($0, /existing target is not owned by stow: /) {
            print substr($0, RSTART + RLENGTH)
        }
    '
)

if [ -z "$conflicts" ]; then
    [ "$status" -eq 0 ] || exit "$status"
    echo "No conflicts detected."
    stow --verbose --dir="$repo" --target="$target" "$@"
    exit 0
fi

echo
echo "Conflicting paths:"
while IFS= read -r rel; do
    printf '  %s -> %s\n' "$target/$rel" "$target/$rel.bak"
done <<EOF
$conflicts
EOF

# Bail if any backup name is already taken
while IFS= read -r rel; do
    backup_path="$target/$rel.bak"
    if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
        printf 'Refusing to operate: backup already exists:\n  %s\n' \
            "$backup_path" >&2
        exit 1
    fi
done <<EOF
$conflicts
EOF

if [ "$assume_yes" != 1 ]; then
    printf 'Back up conflicts and continue? [y/N] '
    read -r answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) ;;
        *) exit 1 ;;
    esac
fi

# From here mutate filesystem
mutating=1

while IFS= read -r rel; do
    source_path="$target/$rel"
    backup_path="$target/$rel.bak"
    if [ -e "$source_path" ] || [ -L "$source_path" ]; then
        mv -- "$source_path" "$backup_path"
        printf 'BACKUP: %s -> %s\n' "$source_path" "$backup_path"
    fi
done <<EOF
$conflicts
EOF

stow --verbose --dir="$repo" --target="$target" "$@"
