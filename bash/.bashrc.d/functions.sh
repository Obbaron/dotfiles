# functions.sh
# sourced by ~/.bashrc via ~/.bashrc.d/

[[ $- != *i* ]] && return

path() {
    echo "$PATH" | tr ":" "\n" | nl
}


# File ops
backup () {
  [ -z "${1}" ] && { echo "Usage: backup <file>"; return 1; }
  [ ! -e "${1}" ] && { echo "Error: file not found" >&2; return 1; }

  cp -- "${1}" "${1}.$(date +%Y%m%d%H%M%S).bak"
}

extract () {
  [ -f "${1}" ] || { echo "Error: file not found" >&2; return 1; }
  case "${1}" in
    *.tar)     tar -xvf  "${1}" ;;
    *.tar.gz)  tar -xvzf "${1}" ;;
    *.tar.bz2) tar -xvjf "${1}" ;;
    *.tar.xz)  tar -xvJf "${1}" ;;
    *.zip)     unzip     "${1}" ;;
    *.rar)     unrar x   "${1}" ;;
    *) echo "Unknown format" >&2; return 1 ;;
  esac
}

gut() {
    local dir=""
    local force=0

    for arg in "$@"; do
        case "$arg" in
            -f|--force)
                force=1
                ;;
            *)
                dir="$arg"
                ;;
        esac
    done

    if [ -z "$dir" ]; then
        echo "Usage: gut [-f|--force] /path/to/directory"
        return 1
    fi

    if [ "$dir" = "/" ]; then
        echo "Cannot gut root."
        return 1
    fi

    if [ "$force" -eq 1 ]; then
        find "$dir" -mindepth 1 -delete
        echo "Directory gutted (forced): $dir"
    else
        echo "About to delete ALL contents of: $dir"
        read -p "Are you sure? (y/N): " confirm

        # Param expansion (bash-only)
        confirm=${confirm,,}

        # Subshell version (posix)
        # confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

        if [ "$confirm" = "y" ] || [ "$confirm" = "yes" ]; then
            find "$dir" -mindepth 1 -delete
            echo "Directory gutted."
        else
            echo "Cancelled."
        fi
    fi
}

pack () {
  [ -z "${1}" ] && { echo "Error: no output file specified" >&2; return 1; }
  [ "${#}" -lt 2 ] && { echo "Error: no input files specified" >&2; return 1; }

  local output="${1}"
  shift

  case "${output}" in
    *.tar)     tar -cvf  "${output}" "$@" ;;
    *.tar.gz)  tar -cvzf "${output}" "$@" ;;
    *.tar.bz2) tar -cvjf "${output}" "$@" ;;
    *.tar.xz)  tar -cvJf "${output}" "$@" ;;
    *.zip)     zip -r    "${output}" "$@" ;;
    *.rar)     rar a     "${output}" "$@" ;;
    *) echo "Unknown format" >&2; return 1 ;;
  esac
}


# Navigation
mkcd() {
  [ -z "${1}" ] && { echo "Usage: mkcd <dir>"; return 1; }
  mkdir -p -- "${1}" && cd -- "${1}"
}

f () {
  local dir
  dir="$(find . -type d | fzf)"

  local output=$?
  if [ $output -eq 130 ]; then
    echo "Cancelled" >&2
    return 130
  elif [ $output -ne 0 ]; then
    echo "Error: fzf failed" >&2
    return $output
  fi

  [ -z "${dir}" ] && {
    echo "No directory selected" >&2
    return 1
  }

  cd -- "${dir}" || return
}

up() {
  local n="${1:-1}"

  [[ "${n}" =~ ^-?[0-9]+$ ]] || {
    echo "Usage: up <integer>" >&2
    return 1
  }

  (( n < 1 )) && n=1

  cd "$(printf '../%.0s' $(seq 1 "${n}"))" || return
}

y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}


# Software
detect_pkg_manager() {
    local pkg_manager="${PKG_MANAGER:-}"
    local distro

    if [ -z "$pkg_manager" ]; then
        [ -f /etc/os-release ] || return 1
        . /etc/os-release || return 1
        [ -n "$ID" ] || return 1
        distro="$ID"

        case "$distro" in
            arch|manjaro|endeavouros|cachyos)
                if command -v paru &>/dev/null; then
                    pkg_manager="paru"
                elif command -v yay &>/dev/null; then
                    pkg_manager="yay"
                else
                    pkg_manager="pacman"
                fi
                ;;
            fedora|fedora-asahi-remix|rhel|centos) pkg_manager="dnf" ;;
            ubuntu|debian|linuxmint) pkg_manager="apt" ;;
            opensuse-leap|opensuse-tumbleweed) pkg_manager="zypper" ;;
            gentoo) pkg_manager="emerge" ;;
            void) pkg_manager="xbps-install" ;;
            *) return 2 ;;
        esac
    fi

    echo "$pkg_manager"
}

install_pkg() {
#   0 = success
#   1 = failed to detect Linux distribution (/etc/os-release missing or invalid)
#   2 = unsupported Linux distribution
#   3 = package manager command failed
    local pkg_manager
    pkg_manager="$(detect_pkg_manager)" || return $?

    case "$pkg_manager" in
        paru|yay)
            "$pkg_manager" -S --noconfirm "$@"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$@"
            ;;
        dnf)
            sudo dnf install -y "$@"
            ;;
        apt)
            sudo apt install -y "$@"
            ;;
        zypper)
            sudo zypper install -y "$@"
            ;;
        emerge)
            sudo emerge "$@"
            ;;
        xbps-install)
            sudo xbps-install -y "$@"
            ;;
        *)
            return 2
            ;;
    esac || return 3
}

update_pkg() {
#   0 = success
#   1 = failed to detect Linux distribution (/etc/os-release missing or invalid)
#   2 = unsupported Linux distribution
#   3 = package manager command failed
    local pkg_manager
    pkg_manager="$(detect_pkg_manager)" || return $?

    case "$pkg_manager" in
        paru|yay)
            "$pkg_manager" -Syu --noconfirm
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
        dnf)
            sudo dnf upgrade -y
            ;;
        apt)
            sudo apt update && sudo apt upgrade -y
            ;;
        zypper)
            sudo zypper refresh && sudo zypper update -y
            ;;
        emerge)
            sudo emerge --sync && sudo emerge -uDU @world
            ;;
        xbps-install)
            sudo xbps-install -Syu
            ;;
        *)
            return 2
            ;;
    esac || return 3
}


# Networking
pubip() { curl -s https://icanhazip.com; }

tsip() { tailscale ip -4; }

isup() {
  [ -z "$1" ] && { echo "Usage: isup <host>" >&2; return 1; }

  if ping -c1 "$1" >/dev/null 2>&1; then
    echo "up"
  else
    echo "down"
  fi
}

ports () {
  [ -n "${1}" ] || { ss -tulnp; return; }

  ss -tulnp | grep -F -i -- "${1}"
}
