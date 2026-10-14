# ~/.bashrc.d/pkg.sh
# Distro-agnostic package manager helpers: ipkg (install) and upkg (update).
#
# Return codes for install_pkg / update_pkg:
#   0 = success
#   1 = failed to detect Linux distribution (/etc/os-release missing or invalid)
#   2 = unsupported Linux distribution
#   3 = package manager command failed

# Set PKG_MANAGER to override package manager detection
[ -n "${PKG_MANAGER:-}" ] || [ -f /etc/os-release ] || return 0


detect_pkg_manager() (
    if [ -n "${PKG_MANAGER:-}" ]; then
        echo "$PKG_MANAGER"
        return 0
    fi

    [ -f /etc/os-release ] || return 1
    . /etc/os-release || return 1
    [ -n "$ID" ] || return 1

    case $ID in
        arch|manjaro|endeavouros|cachyos)
            if _have paru; then echo paru
            elif _have yay; then echo yay
            else echo pacman
            fi
            ;;
        fedora|fedora-asahi-remix|rhel|centos) echo dnf ;;
        ubuntu|debian|linuxmint) echo apt ;;
        opensuse-leap|opensuse-tumbleweed) echo zypper ;;
        gentoo) echo emerge ;;
        void) echo xbps-install ;;
        *) return 2 ;;
    esac
)

install_pkg() {
    local pm
    pm=$(detect_pkg_manager) || return $?

    case $pm in
        paru|yay)     "$pm" -S --noconfirm "$@" ;;
        pacman)       sudo pacman -S --noconfirm "$@" ;;
        dnf)          sudo dnf install -y "$@" ;;
        apt)          sudo apt install -y "$@" ;;
        zypper)       sudo zypper install -y "$@" ;;
        emerge)       sudo emerge "$@" ;;
        xbps-install) sudo xbps-install -y "$@" ;;
        *)            return 2 ;;
    esac || return 3
}

update_pkg() {
    local pm
    pm=$(detect_pkg_manager) || return $?

    case $pm in
        paru|yay)     "$pm" -Syu --noconfirm ;;
        pacman)       sudo pacman -Syu --noconfirm ;;
        dnf)          sudo dnf upgrade -y ;;
        apt)          sudo apt update && sudo apt upgrade -y ;;
        zypper)       sudo zypper refresh && sudo zypper update -y ;;
        emerge)       sudo emerge --sync && sudo emerge -uDU @world ;;
        xbps-install) sudo xbps-install -Syu ;;
        *)            return 2 ;;
    esac || return 3
}

alias ipkg='install_pkg'
alias upkg='update_pkg'
