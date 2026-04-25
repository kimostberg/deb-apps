#!/bin/bash

set -euo pipefail  # FIX: exit on error, undefined vars, and pipe failures

# FIX: correct binary name for the Nextcloud desktop client
if command -v nextcloudcmd &>/dev/null; then
    NEXTCLOUD_BIN="nextcloudcmd"
elif command -v nextcloud &>/dev/null; then
    NEXTCLOUD_BIN="nextcloud"
else
    echo "Nextcloud is not installed. Skipping update."
    exit 0
fi

# Check installed Nextcloud version
installed_nextcloud_version=$("$NEXTCLOUD_BIN" --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)

# Find the latest Nextcloud version on GitHub
latest_nextcloud_version=$(curl -s https://api.github.com/repos/nextcloud-releases/desktop/releases/latest | \
    jq -r '.tag_name' | sed 's/^v//')

# Print installed and latest Nextcloud versions
echo "Installed Nextcloud version: $installed_nextcloud_version"
echo "Latest Nextcloud version:    $latest_nextcloud_version"

# Compare versions and update if necessary
if [ "$latest_nextcloud_version" != "$installed_nextcloud_version" ]; then
    echo "Updating Nextcloud from $installed_nextcloud_version to $latest_nextcloud_version..."

    build_dir="/tmp/Nextcloud-build"
    mkdir -p "$build_dir"

    # FIX: use $latest_nextcloud_version instead of hardcoded version
    source_url="https://github.com/nextcloud-releases/desktop/archive/refs/tags/v${latest_nextcloud_version}.tar.gz"

    echo "Downloading source..."
    wget -O "$build_dir/source.tar.gz" "$source_url"

    echo "Extracting..."
    tar -xzf "$build_dir/source.tar.gz" -C "$build_dir"

    # FIX: use $latest_nextcloud_version instead of hardcoded directory name
    source_dir="$build_dir/desktop-${latest_nextcloud_version}"

    echo "Building..."
    mkdir -p "$source_dir/build"
    cd "$source_dir/build"

    cmake \
        -DCMAKE_PREFIX_PATH="/usr/lib/cmake/Qt6Keychain;/usr/lib/qt6;/usr/lib/x86_64-linux-gnu/cmake/Qt6;/usr/lib/cmake/Qt6Core5Compat;/usr/lib/cmake/KIO;/usr/lib/cmake/CMocka" \
        -DQT_DEBUG_FIND_PACKAGE=ON \
        ..

    make -j"$(nproc)"

    echo "Installing..."
    sudo make install

    # FIX: cd away before cleanup so the shell isn't left in a deleted directory
    cd /tmp
    rm -rf "$build_dir"

    echo "Nextcloud updated to $latest_nextcloud_version successfully."
else
    echo "Nextcloud is already up-to-date (version $installed_nextcloud_version)."
fi