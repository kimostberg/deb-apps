#!/bin/bash

set -euo pipefail

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

# Install build dependencies
sudo nala install -y \
    build-essential \
    cmake \
    wget \
    git \
    libp11-dev \
    qt6-base-dev \
    qt6-tools-dev \
    qttools5-dev \
    qt6-tools-dev-tools \
    libqt6svg6-dev \
    libssl-dev \
    zlib1g-dev \
    extra-cmake-modules \
    libsecret-1-dev \
    qt6-websockets-dev \
    qt6-declarative-dev \
    qt6-networkauth-dev \
    qt6-base-dev-tools \
    qtkeychain-qt6-dev \
    libkf6guiaddons-dev \
    libsqlite3-dev \
    libkf6archive-dev \
    librsvg2-bin \
    qt6-webengine-dev \
    libkf6kio-dev \
    qt6-httpserver-dev \
    libcmocka-dev \
    libqt6core5compat6-dev  # FIX: removed duplicate qt6-declarative-dev

# Build and install KDSingleApplication-qt6
echo "Building KDSingleApplication..."
git clone https://github.com/KDAB/KDSingleApplication.git /tmp/KDSingleApplication
cd /tmp/KDSingleApplication
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DQT_MAJOR_VERSION=6 ..
make -j"$(nproc)"
sudo make install  # FIX: added missing sudo

# Build and install Qt6Keychain
echo "Building Qt6Keychain..."
git clone https://github.com/frankosterfeld/qtkeychain.git /tmp/Qt6Keychain
cd /tmp/Qt6Keychain
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DQT_MAJOR_VERSION=6 -DBUILD_TESTING=OFF ..
make -j"$(nproc)"
sudo make install  # FIX: added missing sudo

# Download the source tarball
echo "Downloading Nextcloud $latest_version source..."
wget -O "$build_dir/source.tar.gz" "$source_url"

# Extract the tarball
echo "Extracting..."
tar -xzf "$build_dir/source.tar.gz" -C "$build_dir"

# Build Nextcloud
echo "Building Nextcloud..."
cd "$source_dir"  # FIX: uses dynamic $source_dir, not hardcoded path
mkdir build
cd build
cmake \
    -DCMAKE_PREFIX_PATH="/usr/lib/cmake/Qt6Keychain;/usr/lib/qt6;/usr/lib/x86_64-linux-gnu/cmake/Qt6;/usr/lib/cmake/Qt6Core5Compat;/usr/lib/cmake/KIO;/usr/lib/cmake/CMocka" \
    -DQT_DEBUG_FIND_PACKAGE=ON \
    ..
make -j"$(nproc)"

# Install
echo "Installing Nextcloud $latest_version..."
sudo make install

# Clean up
cd /tmp  # FIX: cd away before deleting current directory
rm -rf "$build_dir"
rm -rf /tmp/KDSingleApplication
rm -rf /tmp/Qt6Keychain  # FIX: added missing Qt6Keychain cleanup

echo "Nextcloud $latest_version installed successfully."