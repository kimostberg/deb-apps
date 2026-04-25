#!/bin/bash

set -euo pipefail

if command -v zoom &>/dev/null; then

    # Check installed Zoom version
    installed_version=$(dpkg-query -W -f='${Version}' zoom 2>/dev/null | grep -oP '^[0-9]+\.[0-9]+\.[0-9]+')

    # Find the latest Zoom version via redirect header
    latest_version=$(curl -sI https://zoom.us/client/latest/zoom_amd64.deb | \
        grep -i '^location:' | \
        sed -n 's#.*/prod/\([0-9]\+\.[0-9]\+\.[0-9]\+\)\.[0-9]\+/zoom_amd64\.deb.*#\1#p' | \
        tr -d '[:space:]')  # FIX: strip any trailing whitespace/CR from header

    # FIX: guard against empty version strings
    if [[ -z "$installed_version" ]]; then
        echo "ERROR: Could not determine installed Zoom version."
        exit 1
    fi
    if [[ -z "$latest_version" ]]; then
        echo "ERROR: Could not fetch latest Zoom version. Check your internet connection."
        exit 1
    fi

    echo "Installed Zoom version: $installed_version"
    echo "Latest Zoom version:    $latest_version"

    if [ "$latest_version" != "$installed_version" ]; then
        echo "Updating Zoom from $installed_version to $latest_version..."

        temp_dir="/tmp/zoom"
        mkdir -p "$temp_dir"
        zoom_url="https://zoom.us/client/latest/zoom_amd64.deb"

        wget -O "$temp_dir/zoom.deb" "$zoom_url"

        # FIX: use dpkg + nala fix for local .deb to ensure dependencies resolve
        sudo dpkg -i "$temp_dir/zoom.deb" || sudo nala install -f -y

        rm -rf "$temp_dir"
        echo "Zoom updated to $latest_version successfully."
    else
        echo "Zoom is already up-to-date (version $installed_version)."
    fi

else
    echo "Zoom is not installed. Skipping Zoom update."
fi