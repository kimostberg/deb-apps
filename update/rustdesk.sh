#!/bin/bash

set -euo pipefail

if command -v rustdesk &>/dev/null; then

    # Check installed RustDesk version
    installed_rustdesk_version=$(rustdesk --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    # Find the latest RustDesk version on GitHub
    github_response=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest)

    # FIX: check for GitHub API rate limit or error
    if echo "$github_response" | jq -e '.message' &>/dev/null; then
        echo "ERROR: GitHub API returned an error:"
        echo "$github_response" | jq -r '.message'
        exit 1
    fi

    latest_rustdesk_version=$(echo "$github_response" | jq -r '.tag_name' | sed 's/^v//')

    # FIX: guard against empty version strings
    if [[ -z "$installed_rustdesk_version" ]]; then
        echo "ERROR: Could not determine installed RustDesk version."
        exit 1
    fi
    if [[ -z "$latest_rustdesk_version" ]]; then
        echo "ERROR: Could not fetch latest RustDesk version."
        exit 1
    fi

    echo "Installed RustDesk version: $installed_rustdesk_version"
    echo "Latest RustDesk version:    $latest_rustdesk_version"

    if [ "$latest_rustdesk_version" != "$installed_rustdesk_version" ]; then
        echo "Updating RustDesk from $installed_rustdesk_version to $latest_rustdesk_version..."

        temp_dir="/tmp/rustdesk"
        mkdir -p "$temp_dir"

        # FIX: RustDesk release assets use the tag with 'v' prefix in the URL path
        rustdesk_url="https://github.com/rustdesk/rustdesk/releases/download/${latest_rustdesk_version}/rustdesk-${latest_rustdesk_version}-x86_64.deb"

        wget -O "$temp_dir/rustdesk.deb" "$rustdesk_url"

        # FIX: use dpkg -i + nala install -f for proper local .deb dep resolution
        sudo dpkg -i "$temp_dir/rustdesk.deb" || sudo nala install -f -y

        rm -rf "$temp_dir"
        echo "RustDesk updated to $latest_rustdesk_version successfully."
    else
        echo "RustDesk is already up-to-date (version $installed_rustdesk_version)."
    fi

else
    echo "RustDesk is not installed. Skipping update."
fi
