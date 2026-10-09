#!/bin/bash

set -euo pipefail  # exit on error, undefined vars, and pipe failures

# --- Qt configuration ---------------------------------------------------
QT_VERSION="6.10.0"
QT_ARCH="linux_gcc_64"          # aqtinstall arch name
QT_SUBDIR="gcc_64"              # resulting subfolder name under the version dir
QT_ROOT="$HOME/Qt"              # reasonable, non-sudo install location
QT_PREFIX="$QT_ROOT/$QT_VERSION/$QT_SUBDIR"
QT_MODULES=(qtwebsockets qt5compat)   # add/remove modules as the build needs them

ensure_qt() {
    local cmake_cfg="$QT_PREFIX/lib/cmake/Qt6/Qt6Config.cmake"
    local websockets_cfg="$QT_PREFIX/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake"

    if [[ -f "$cmake_cfg" && -f "$websockets_cfg" ]]; then
        echo "Qt $QT_VERSION (with WebSockets) already present at $QT_PREFIX"
        return
    fi

    echo "Qt $QT_VERSION with required modules not found at $QT_PREFIX — installing..."

    if ! command -v aqt &>/dev/null && ! python3 -m aqt --help &>/dev/null 2>&1; then
        echo "Installing aqtinstall..."
        pip install --user aqtinstall --break-system-packages
    fi

    local AQT_CMD="aqt"
    command -v aqt &>/dev/null || AQT_CMD="python3 -m aqt"

    mkdir -p "$QT_ROOT"
    $AQT_CMD install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_ROOT" \
        -m "${QT_MODULES[@]}"

    if [[ ! -f "$cmake_cfg" ]]; then
        echo "Qt install finished but Qt6Config.cmake not found at expected path: $cmake_cfg"
        exit 1
    fi
    if [[ ! -f "$websockets_cfg" ]]; then
        echo "Qt install finished but WebSockets module config not found at expected path: $websockets_cfg"
        exit 1
    fi

    echo "Qt $QT_VERSION installed successfully at $QT_PREFIX"
}

# --- Nextcloud client binary detection ----------------------------------
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

    ensure_qt

    build_dir="/tmp/Nextcloud-build"
    mkdir -p "$build_dir"

    source_url="https://github.com/nextcloud-releases/desktop/archive/refs/tags/v${latest_nextcloud_version}.tar.gz"

    echo "Downloading source..."
    wget -O "$build_dir/source.tar.gz" "$source_url"

    echo "Extracting..."
    tar -xzf "$build_dir/source.tar.gz" -C "$build_dir"

    source_dir="$build_dir/desktop-${latest_nextcloud_version}"

    echo "Building..."
    mkdir -p "$source_dir/build"
    cd "$source_dir/build"

    cmake \
        -DCMAKE_PREFIX_PATH="$QT_PREFIX;/usr/lib/cmake/Qt6Keychain;/usr/lib/cmake/Qt6Core5Compat;/usr/lib/cmake/KIO;/usr/lib/cmake/CMocka" \
        -DQT_DEBUG_FIND_PACKAGE=ON \
        ..

    make -j"$(nproc)"

    echo "Installing..."
    sudo make install

    # cd away before cleanup so the shell isn't left in a deleted directory
    cd /tmp
    rm -rf "$build_dir"

    echo "Nextcloud updated to $latest_nextcloud_version successfully."
else
    echo "Nextcloud is already up-to-date (version $installed_nextcloud_version)."
fi
