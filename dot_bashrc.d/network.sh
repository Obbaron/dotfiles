# ~/.bashrc.d/network.sh
# network helpers

if _have wget; then
    alias wget='wget -c'
fi

# public ip4 address
if _have curl; then
    pubip() { curl -s https://icanhazip.com; }
elif _have wget; then
    pubip() { command wget -qO- https://icanhazip.com; }
fi

# tailscale ip
if _have tailscale; then
    tsip() { tailscale ip -4; }
fi

if _have ping; then
    isup() {
        [ -z "$1" ] && { echo "Usage: isup <host>" >&2; return 1; }

        if ping -c1 "$1" >/dev/null 2>&1; then
            echo "up"
        else
            echo "down"
        fi
    }
fi

# ports <filter>: listening sockets, optionally filtered
if _have ss; then
    ports() {
        [ -n "$1" ] || { ss -tulnp; return; }

        ss -tulnp | grep -F -i -- "$1"
    }
fi
