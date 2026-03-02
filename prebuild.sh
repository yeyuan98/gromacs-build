#!/bin/bash
set -e

echo "==================================="
echo "PREBUILD: Setting up build environment"
echo "==================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Detected OS: $PRETTY_NAME"
fi

# Install C++ build toolchain
if command -v apt-get &> /dev/null; then
    echo "Installing build dependencies..."
    sudo apt-get update
    sudo apt-get install -y cmake g++ make
elif command -v brew &> /dev/null; then
    echo "Installing build dependencies via Homebrew..."
    brew install cmake
fi

# Verify installations
echo "Verifying toolchain..."
cmake --version
g++ --version | head -n1
make --version | head -n1

echo "Prebuild environment setup complete"
echo ""
