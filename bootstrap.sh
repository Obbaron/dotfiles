#!/bin/sh
# bootstrap.sh
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Obbaron/dotfiles/main/bootstrap.sh | sh
#
# Config:
#   REPO       owner/name
#   REPO_URL   chezmoi source repo URL
#   DRY_RUN    report actions but change nothing
#
# Examples:
#   ./bootstrap.sh
#   REPO_URL=git@github.com:Obbaron/dotfiles.git ./bootstrap.sh
#   DRY_RUN=1 ./bootstrap.sh

set -eu

REPO="${REPO:-Obbaron/dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/$REPO.git}"

BASHRC_URL="https://raw.githubusercontent.com/$REPO/main/dot_bashrc"
BASHRC="${HOME:?HOME must be set}/.bashrc"

DRY_RUN="${DRY_RUN:-}"

log() {
    lvl="$1"
    color=""
    reset=""
    shift

    if [ -z "${NO_COLOR:-}" ] && [ -t 2 ]; then
        case "$lvl" in
            debug) color="$(printf '\033')[2m"  ;;
            info)  color="$(printf '\033')[36m" ;;
            warn)  color="$(printf '\033')[33m" ;;
            error) color="$(printf '\033')[31m" ;;
        esac
        reset="$(printf '\033')[0m"
    fi

    printf '[install] %s%-5s%s %s\n' "$color" "$lvl" "$reset" "$*" >&2
}
say() {
    log info "$@"
}
die() {
    log error "$@"
    exit 1
}

run_priv() {
    if [ -n "$DRY_RUN" ]; then
        printf '[install] + %s\n' "$*" >&2
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        die "need root or sudo to run: $*"
    fi
}

detect_pkg_mgr() {
    for pm in apt-get dnf dnf5 yum pacman zypper apk emerge xbps-install; do
        if command -v "$pm" >/dev/null 2>&1; then
            printf '%s\n' "$pm"
            return 0
        fi
    done

    return 1
}

install_pkgs() {
    [ "$#" -ge 1 ] || return 0

    mgr=$(detect_pkg_mgr) || die "no supported package manager found"

    say "installing via $mgr: $*"

    case "$mgr" in
        apt-get)
            run_priv env DEBIAN_FRONTEND=noninteractive apt-get update
            run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            ;;

        dnf|dnf5|yum)
            run_priv "$mgr" install -y "$@"
            ;;

        pacman)
            run_priv pacman -Sy --noconfirm "$@"
            ;;

        zypper)
            run_priv zypper --non-interactive install "$@"
            ;;

        apk)
            run_priv apk add "$@"
            ;;

        emerge)
            run_priv emerge "$@"
            ;;

        xbps-install)
            run_priv xbps-install -Sy "$@"
            ;;

        *)
            die "unsupported manager: $mgr"
            ;;
    esac
}

main() {
    need=""

    # Git
    if command -v git >/dev/null 2>&1; then
        say "git ok: $(git --version)"
    else
        say "git not found; will install git"
        need="$need git"
    fi

    # curl
    if command -v curl >/dev/null 2>&1; then
        say "curl ok"
    else
        say "curl not found; will install curl"
        need="$need curl"
    fi

    # .bashrc
    if [ -n "$DRY_RUN" ]; then
        say "would download $BASHRC_URL to $BASHRC"
        say "would source $BASHRC"
    else
        if [ -f "$BASHRC" ] && [ -e "$BASHRC.bak" ]; then
            die "both $BASHRC and $BASHRC.bak exist; please clean them up before continuing"
        fi

        BASHRC_TMP=$(mktemp /tmp/bashrc.bootstrap.XXXXXX) \
            || die "failed to create temporary file"

        say "downloading .bashrc from $BASHRC_URL"

        if curl -fsSL "$BASHRC_URL" -o "$BASHRC_TMP"; then
            if [ -f "$BASHRC" ]; then
                say "backing up existing .bashrc"
                cp -p "$BASHRC" "$BASHRC.bak" \
                    || {
                        rm -f "$BASHRC_TMP"
                        die "failed to back up existing $BASHRC"
                    }
            fi

            mv "$BASHRC_TMP" "$BASHRC" \
                || {
                    rm -f "$BASHRC_TMP"
                    die "failed to install $BASHRC"
                }

            say "installed $BASHRC"
        else
            rm -f "$BASHRC_TMP"
            die "failed to download .bashrc from $BASHRC_URL"
        fi

        say "sourcing $BASHRC"
        . "$BASHRC"
    fi

    # shellcheck disable=SC2086
    [ -z "$need" ] || install_pkgs $need

    if [ -z "$DRY_RUN" ]; then
        command -v git >/dev/null 2>&1 \
            || die "git still unavailable after installation"

        command -v curl >/dev/null 2>&1 \
            || die "curl still unavailable after installation"
    fi

    # Chezmoi
    say "installing chezmoi and applying dotfiles from $REPO_URL"

    if [ -n "$DRY_RUN" ]; then
        say "+ sh -c \"\$(curl -fsLS https://get.chezmoi.io)\" -- init --apply $REPO_URL"
        return 0
    fi

    exec sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply "$REPO_URL"
}

main "$@"
