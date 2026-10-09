#!/bin/bash

set -euo pipefail

# --- Qt configuration ----------------------------------------------------
QT_VERSION="6.10.0"
QT_ARCH="linux_gcc_64"                 # aqtinstall arch name
QT_SUBDIR="gcc_64"                     # resulting subfolder name under the version dir
QT_ROOT="$HOME/Qt"                     # user-local install, no sudo needed for Qt itself
QT_PREFIX="$QT_ROOT/$QT_VERSION/$QT_SUBDIR"
# Add/remove modules here if the build complains about a missing Qt component
QT_MODULES=(qtwebsockets qt5compat qtdeclarative qtnetworkauth qtsvg qttools qthttpserver)

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

echo "Fetching latest Nextcloud desktop version from GitHub..."

# Fetch the latest version dynamically
latest_version=$(curl -s https://api.github.com/repos/nextcloud-releases/desktop/releases/latest | \
    jq -r '.tag_name' | sed 's/^v//')

if [[ -z "$latest_version" ]]; then
    echo "ERROR: Could not fetch latest Nextcloud version. Check your internet connection or jq installation."
    exit 1
fi

echo "Latest Nextcloud version: $latest_version"

source_url="https://github.com/nextcloud-releases/desktop/archive/refs/tags/v${latest_version}.tar.gz"
build_dir="/tmp/Nextcloud-build"
source_dir="$build_dir/desktop-${latest_version}"

# Create build directory
mkdir -p "$build_dir"

# Bootstrap Qt 6.10 (with WebSockets, etc.) before anything else needs it
ensure_qt

# Install non-Qt build dependencies (Qt itself now comes from ~/Qt, not apt,
# since Debian's packaged Qt6 is older than what this build needs)
sudo nala install -y \
    build-essential \
    cmake \
    wget \
    git \
    libp11-dev \
    libssl-dev \
    zlib1g-dev \
    extra-cmake-modules \
    libsecret-1-dev \
    libkf6guiaddons-dev \
    libsqlite3-dev \
    libkf6archive-dev \
    librsvg2-bin \
    libkf6kio-dev \
    libcmocka-dev

# Build and install KDSingleApplication-qt6 (into the local Qt prefix, no sudo needed)
echo "Building KDSingleApplication..."
git clone https://github.com/KDAB/KDSingleApplication.git /tmp/KDSingleApplication
cd /tmp/KDSingleApplication
mkdir build && cd build
cmake \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$QT_PREFIX" \
    -DQT_MAJOR_VERSION=6 ..
make -j"$(nproc)"
make install  # no sudo: installing into user-owned $QT_PREFIX

# Build and install Qt6Keychain (into the local Qt prefix, no sudo needed)
echo "Building Qt6Keychain..."
git clone https://github.com/frankosterfeld/qtkeychain.git /tmp/Qt6Keychain
cd /tmp/Qt6Keychain
mkdir build && cd build
cmake \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
    -DCMAKE_INSTALL_PREFIX="$QT_PREFIX" \
    -DQT_MAJOR_VERSION=6 -DBUILD_TESTING=OFF ..
make -j"$(nproc)"
make install  # no sudo: installing into user-owned $QT_PREFIX

# Download the source tarball
echo "Downloading Nextcloud $latest_version source..."
wget -O "$build_dir/source.tar.gz" "$source_url"

# Extract the tarball
echo "Extracting..."
tar -xzf "$build_dir/source.tar.gz" -C "$build_dir"

# Build Nextcloud
echo "Building Nextcloud..."
cd "$source_dir"
mkdir build
cd build
cmake \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX;/usr/lib/cmake/KIO;/usr/lib/cmake/CMocka" \
    -DQT_DEBUG_FIND_PACKAGE=ON \
    ..
make -j"$(nproc)"

# Install
echo "Installing Nextcloud $latest_version..."
sudo make install

# Clean up
cd /tmp
rm -rf "$build_dir"
rm -rf /tmp/KDSingleApplication
rm -rf /tmp/Qt6Keychain

echo "Nextcloud $latest_version installed successfully."
