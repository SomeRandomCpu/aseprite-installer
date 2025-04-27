# This script was written by Duplicake (https://duplicake.fyi) and forked from https://github.com/KtheVeg/aseprite-installer
# Tested in a fresh installation of Fedora 42. Results may vary

# LICENSE: Follows the MIT 3.0 license
#!/bin/bash

set -e
set -u
set -o pipefail

DEFAULT_INSTALL_DIR="$PWD/aseprite"
DEFAULT_BUILD_DIR="$PWD/aseprite_build_temp"

installDirectory="${1:-$DEFAULT_INSTALL_DIR}"
buildDirectory="${2:-$DEFAULT_BUILD_DIR}"

log_info() {
    echo "INFO: $1"
}

log_warn() {
    echo "WARN: $1"
}

log_error() {
    echo "ERROR: $1" >&2
    exit 1
}

echo "Installing Aseprite for Fedora"
echo "=============================="
echo

log_info "Install Location: $installDirectory"
log_info "Build Location:   $buildDirectory"
echo "Note: Sudo access required for dependency download. To skip, export SKIPDEPS=1"
echo

if [[ "${SKIPDEPS:-0}" -ne 1 ]]; then
    log_info "Downloading required dependencies using dnf..."
    sudo dnf install -y \
        gcc-c++ \
        cmake \
        ninja-build \
        libX11-devel \
        libXcursor-devel \
        mesa-libGL-devel \
        fontconfig-devel \
        git \
        unzip \
        wget || log_error "Dependency installation failed. Cannot continue."
    log_info "Dependencies installed successfully."
else
    log_warn "Dependency download manually skipped via SKIPDEPS=1."
fi

log_info "Setting up build directory structure in $buildDirectory"
mkdir -p "$buildDirectory/deps/skia"

cd "$buildDirectory/deps"

SKIA_VERSION="m102-861e5ab743"
SKIA_REPO="https://github.com/aseprite/skia/releases"
SKIA_FILENAME="Skia-Linux-Release-x64-libstdc++.zip"
SKIA_URL="${SKIA_REPO}/download/${SKIA_VERSION}/${SKIA_FILENAME}"

if [ ! -f "$SKIA_FILENAME" ]; then
    log_info "Downloading Skia Build ($SKIA_VERSION x64)..."
    wget -O "$SKIA_FILENAME" "$SKIA_URL" || log_error "Failed to download Skia."
else
    log_info "Skia archive already downloaded."
fi

log_info "Extracting Skia..."
unzip -o "$SKIA_FILENAME" -d skia || log_error "Failed to extract Skia."

cd "$buildDirectory"

if [ ! -d "aseprite/.git" ]; then
    log_info "Downloading Aseprite Source Code..."
    git clone --recursive https://github.com/aseprite/aseprite.git || log_error "Failed to clone Aseprite source."
    cd aseprite
else
    log_info "Aseprite source directory found. Updating..."
    cd aseprite
    git pull --recurse-submodules || log_warn "Failed to update Aseprite source. Continuing with existing version."
fi

log_info "Aseprite source code ready. Building..."
mkdir -p build
cd build

log_info "Generating build files with CMake..."
cmake \
  -DCMAKE_INSTALL_PREFIX="$installDirectory" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLAF_OS_BACKEND=skia \
  -DSKIA_DIR="$buildDirectory/deps/skia" \
  -DSKIA_LIBRARY_DIR="$buildDirectory/deps/skia/out/Release-x64" \
  -DSKIA_LIBRARY="$buildDirectory/deps/skia/out/Release-x64/libskia.a" \
  -G Ninja \
  .. || log_error "CMake configuration failed."

log_info "Building Aseprite using Ninja..."
ninja aseprite || log_error "Aseprite build failed."

log_info "Installing Aseprite..."
ninja install || log_error "Aseprite installation failed."

echo
echo "=============================="
echo "-- ASEPRITE INSTALLATION COMPLETE --"
echo "Aseprite installed to: $installDirectory/bin"
echo "To run, execute:       $installDirectory/bin/aseprite"
echo "To uninstall, delete:  $installDirectory"
echo "=============================="
echo "Thanks for using this Aseprite auto-compiler script!"
