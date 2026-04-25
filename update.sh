#!/bin/bash

set -euo pipefail

# FIX: proper sudo credential caching instead of 'sudo echo'
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_DIR="$SCRIPT_DIR/update"

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