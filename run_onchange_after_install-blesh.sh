#!/usr/bin/env bash
# Install / update ble.sh (Bash Line Editor) from source into ~/.local.
# chezmoi re-runs this whenever its contents change, so bump the date below to
# force a rebuild to the latest upstream. Needs: git, make, gawk.
#
# ble.sh ref: master (bump to reinstall) 2026-10-14

set -euo pipefail

prefix="$HOME/.local"

for dep in git make gawk; do
    command -v "$dep" >/dev/null 2>&1 || { echo "ble.sh: $dep is required, skipping install" >&2; exit 0; }
done

echo "Installing/updating ble.sh -> $prefix/share/blesh ..."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git clone --recursive --depth 1 --shallow-submodules \
    https://github.com/akinomyoga/ble.sh.git "$tmp/ble.sh"
make -C "$tmp/ble.sh" install PREFIX="$prefix"

echo "ble.sh ready. Open a new shell (or run: source ~/.bashrc) to load it."
