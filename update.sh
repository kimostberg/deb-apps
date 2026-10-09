#!/bin/bash

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-update: fetch the newest version of this script first, then re-run it.
# ---------------------------------------------------------------------------
RAW_URL="https://raw.githubusercontent.com/kimostberg/deb-apps/main/update.sh"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "$SELF")"

self_update() {
    # Already re-executed after an update: don't check again (prevents loops)
    [[ "${UPDATE_SH_REEXEC:-}" == "1" ]] && return 0

    echo "[*] Checking for a newer version of this script..."
    local before after tmp
    before="$(sha256sum "$SELF" | cut -d' ' -f1)"

    if command -v git &>/dev/null && git -C "$SELF_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        # Script lives in a git clone: pull (also refreshes the update/ folder)
        if ! git -C "$SELF_DIR" pull --ff-only; then
            echo "[!] git pull failed. Continuing with the local copy."
            return 0
        fi
    elif command -v curl &>/dev/null; then
        # Plain downloaded script: fetch just this file
        tmp="$(mktemp)"
        if curl -fsSL "$RAW_URL" -o "$tmp" && [[ -s "$tmp" ]]; then
            chmod --reference="$SELF" "$tmp"
            mv "$tmp" "$SELF"   # atomic replace; running bash keeps the old inode
        else
            rm -f "$tmp"
            echo "[!] Could not download the latest script. Continuing with the local copy."
            return 0
        fi
    else
        echo "[!] Neither git nor curl found. Skipping self-update."
        return 0
    fi

    after="$(sha256sum "$SELF" | cut -d' ' -f1)"
    if [[ "$before" != "$after" ]]; then
        echo "[*] Script updated. Restarting with the new version..."
        UPDATE_SH_REEXEC=1 exec "$SELF" "$@"
    else
        echo "[*] Script is already up to date."
    fi
}

self_update "$@"

# ---------------------------------------------------------------------------
# Main update logic
# test change ---------------------------------------------------------------------------

# Proper sudo credential caching instead of 'sudo echo'
sudo -v

# Keep sudo alive for the duration of the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

echo "========================================"
echo " System Update — $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# Ensure nala is installed
if ! command -v nala &>/dev/null; then
    echo "[*] Nala not found. Installing via apt..."
    sudo apt update && sudo apt install -y nala
else
    echo "[*] Nala is already installed."
fi

# System packages
echo ""
echo "[*] Running full system upgrade..."
sudo nala full-upgrade -y

# Flatpak
echo ""
if command -v flatpak &>/dev/null; then
    echo "[*] Updating Flatpak packages (user)..."
    flatpak update -y --user
    echo "[*] Updating Flatpak packages (system)..."
    sudo flatpak update -y
else
    echo "[*] Flatpak is not installed. Skipping."
fi

# Run scripts from the update/ folder
UPDATE_DIR="$SELF_DIR/update"

echo ""
if [[ -d "$UPDATE_DIR" ]]; then
    echo "[*] Running update scripts from $UPDATE_DIR..."
    for script in "$UPDATE_DIR"/*.sh; do
        [[ -f "$script" ]] || continue  # skip if no .sh files found
        echo ""
        echo "--- Running: $(basename "$script") ---"
        bash "$script"
    done
    echo ""
    echo "[*] All update scripts completed."
else
    echo "[*] No update/ directory found at $UPDATE_DIR. Skipping."
fi

echo ""
echo "========================================"
echo " Update complete — $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
