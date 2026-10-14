# ~/.bashrc.d/network.sh
# network helpers

if have wget; then
    alias wget='wget -c'
fi

# public ip4 address
if have curl; then
    pubip() { curl -s https://icanhazip.com; }
elif have wget; then
    pubip() { command wget -qO- https://icanhazip.com; }
fi

# tailscale ip
if have tailscale; then
    tsip() { tailscale ip -4; }
fi

if have ping; then
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
if have ss; then
    ports() {
        [ -n "$1" ] || { ss -tulnp; return; }

        ss -tulnp | grep -F -i -- "$1"
    }
fi
